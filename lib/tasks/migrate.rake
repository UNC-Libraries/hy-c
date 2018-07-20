namespace :cdr do
  # coding: utf-8
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'

  # Must include the email address of a valid user in order to ingest files
  DEPOSITOR_EMAIL = 'admin@example.com'

  # Sample data is currently stored in the hyrax/lib/tasks/migration/tmp directory.  Each object is stored in a
  # directory labelled with its uuid. Container objects only contain a metadata file and are stored as
  # {uuid}/uuid:{uuid}-object.xml. File objects contain a metadata file and the file to be imported which are stored in
  # the same directory as {uuid}/uuid:{uuid}.xml and {uuid}/{uuid}-DATA_FILE.*, respectively.

  namespace :migration do

    desc 'batch migrate generic files from FOXML file'
    task :items, [:collection_objects_file, :objects_file, :binaries_file, :work_type, :admin_set, :mapping_file] => :environment do |t, args|
      @work_type = args[:work_type]
      @admin_set = args[:admin_set]

      # Hash of all binaries in storage directory
      @binary_hash = Hash.new
      File.open(args[:binaries_file]) do |file|
        file.each do |line|
          value = line.strip
          key = value.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
          @binary_hash[key] = value
        end
      end

      # Hash of all objects in storage directory
      @object_hash = Hash.new
      File.open(args[:objects_file]) do |file|
        file.each do |line|
          value = line.strip
          key = value.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
          @object_hash[key] = value
        end
      end

      # Create file mapping new and old ids
      @csv_output = args[:mapping_file]
      if !File.exist?(@csv_output)
        @csv_output = File.new(@csv_output, 'w')
      end

      metadata_list = args[:collection_objects_file]
      migrate_objects(metadata_list)
    end

    def migrate_objects(metadata_list)
      metadata_files = Array.new
      File.open(metadata_list) do |file|
        file.each do |line|
          metadata_files.append(line.strip)
        end
      end

      puts 'Object count: '+metadata_files.count.to_s

      metadata_files.each do |file|
        uuid = file.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
        # Assuming uuid for metadata and binary are the same
        if @binary_hash[uuid].blank?
          metadata_fields = metadata(file)

          puts 'Number of files: '+metadata_fields[:files].count.to_s

          if metadata_fields[:files][0].match(/.+\.xml/)
            resource = metadata_fields[:resource]
            resource.save!

            # Record old and new ids for works
            CSV.open(@csv_output, 'a+') do |csv|
              csv << [uuid, resource.id]
            end

            ingest_files(resource: resource, files: metadata_fields[:files])
          end
        end
      end
    end
   
    def ingest_files(parent: nil, resource: nil, files: [])
      ordered_members = []

      files.each do |f|
        file_metadata = metadata(f)
        file_set = ingest_file(parent: resource, resource: file_metadata[:resource], f: file_metadata[:files][0])
        ordered_members << file_set if file_set
      end

      resource.ordered_members = ordered_members
    end

    def ingest_file(parent: nil, resource: nil, f: nil)
      file_set = FileSet.create(resource)
      actor = Hyrax::Actors::FileSetActor.new(file_set, User.find_by_email(DEPOSITOR_EMAIL))
      actor.create_metadata(resource.slice(:visibility, :visibility_during_lease, :visibility_after_lease,
                                            :lease_expiration_date, :embargo_release_date, :visibility_during_embargo,
                                            :visibility_after_embargo))
      actor.create_content(File.open(f))
      actor.attach_to_work(parent)

      # Record old and new ids for files
      CSV.open(@csv_output, 'a+') do |csv|
        csv << [f.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/), file_set.id]
      end

      file_set
    end
    
    def metadata(file)
      metadata = Nokogiri::XML(File.open(file))

      #get the uuid of the object
      uuid = metadata.at_xpath('foxml:digitalObject/@PID', MigrationConstants::NS).value.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      puts 'getting metadata for: '+uuid

      file_full = Array.new(0)
      representative = ''
      visibility_during_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      visibility_after_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      embargo_release_date = ''
      visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      if !@binary_hash[uuid].blank?
        file_full << @binary_hash[uuid]
      end

      #get the date_created
      date_created_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'model#createdDate')]/@VALUE", MigrationConstants::NS).to_s
      date_created = DateTime.strptime(date_created_string, '%Y-%m-%dT%H:%M:%S.%N%Z').strftime('%Y-%m-%d') unless date_created_string.nil?
      #get the modifiedDate
      date_modified_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'view#lastModifiedDate')]/@VALUE", MigrationConstants::NS).to_s
      date_modified = DateTime.strptime(date_modified_string, '%Y-%m-%dT%H:%M:%S.%N%Z').strftime('%Y-%m-%d') unless date_modified_string.nil?
      MigrationLogger.info 'Get the current version of MODS'
      mods_version = metadata.xpath("//foxml:datastream[contains(@ID, 'MD_DESCRIPTIVE')]//foxml:xmlContent//mods:mods", MigrationConstants::NS).last

      if !mods_version
        MigrationLogger.fatal 'No MODS datastream available'
        return
      end

      title = mods_version.xpath('mods:titleInfo//mods:title', MigrationConstants::NS).text

      rdf_version = metadata.xpath("//foxml:xmlContent//rdf:RDF", MigrationConstants::NS).last
      if rdf_version.to_s.match(/contains/)
        contained_files = rdf_version.xpath("rdf:Description/*[local-name() = 'contains']/@rdf:resource", MigrationConstants::NS)
        contained_files.each do |contained_file|
          tmp_uuid = contained_file.to_s.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
          file_full << @object_hash[tmp_uuid]
        end

        if file_full.count > 1
          representative = rdf_version.xpath('rdf:Description/*[local-name() = "defaultWebObject"]/@rdf:resource', MigrationConstants::NS).to_s.split('/')[1]
          if representative
            representative = @object_hash[representative.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)]
            file_full -= [representative]
            file_full = [representative] + file_full
          end
        end
      end

      creators = mods_version.xpath('mods:name//mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath('mods:name//mods:namePart', MigrationConstants::NS)
      contributors = mods_version.xpath('mods:name//mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath('mods:name//mods:namePart',MigrationConstants::NS)
      keywords = mods_version.xpath("mods:note[contains(@displayLabel, 'Keywords')]", MigrationConstants::NS).map(&:text)
      keywords.uniq!

      # original_filename = file_version.attribute('LABEL').to_s
      subjects = mods_version.xpath('mods:subject',MigrationConstants::NS).map(&:text)
      description = mods_version.xpath('mods:abstract',MigrationConstants::NS).text.gsub(/\n/,' ').gsub(/\t/,' ')
      description = HTMLEntities.new.decode description
      date = mods_version.xpath('mods:dateCreate',MigrationConstants::NS).text
      identifier = mods_version.xpath('mods:identifier',MigrationConstants::NS).map(&:text)
      related_url = mods_version.xpath('mods:location//mods:url', MigrationConstants::NS).map(&:text)
      resource_type = mods_version.xpath('mods:genre', MigrationConstants::NS).text.strip

      if resource_type == 'Journal Article'
        resource_type = 'Article'
      end

      publisher = mods_version.xpath('mods:originInfo//mods:publisher',MigrationConstants::NS).text
      language = mods_version.xpath('mods:language//mods:languageTerm',MigrationConstants::NS).text

      if rdf_version.to_s.match(/metadata-patron/)
        patron = rdf_version.xpath("rdf:Description/*[local-name() = 'metadata-patron']", MigrationConstants::NS).text
        if patron == 'public'
          if rdf_version.to_s.match(/contains/)
            visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
          else
            visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
          end
        end
      elsif rdf_version.to_s.match(/embargo-until/)
        embargo_release_date = Date.parse rdf_version.xpath("rdf:Description/*[local-name() = 'embargo-until']", MigrationConstants::NS).text
        visibility = visibility_during_embargo
      elsif rdf_version.to_s.match(/isPublished/)
        published = rdf_version.xpath("rdf:Description/*[local-name() = 'isPublished']", MigrationConstants::NS).text
        if published == 'no'
          visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        end
      elsif rdf_version.to_s.match(/inheritPermissions/)
        inherit = rdf_version.xpath("rdf:Description/*[local-name() = 'inheritPermissions']", MigrationConstants::NS).text
        if inherit == 'false'
          visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        end
      elsif rdf_version.to_s.match(/cdr-role:patron>authenticated/)
        authenticated = rdf_version.xpath("rdf:Description/*[local-name() = 'patron']", MigrationConstants::NS).text
        if authenticated == 'authenticated'
          visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
        end
      end

      if language == 'eng'
        language = 'English'
      end

      work_attributes = {
          'title'=>title,
          'creator'=>creators,
          'date_created'=>[(Date.try(:edtf, date_created) || date_created).to_s],
          'keyword'=>keywords,
          'date_modified'=>(Date.try(:edtf, date_modified) || date_modified).to_s,
          'contributor'=>contributors,
          'description'=>[description],
          'identifier'=>identifier,
          'related_url' => related_url,
          'publisher'=>[publisher],
          'subject'=>subjects,
          'resource_type'=>[resource_type],
          'language'=>[language],
          'visibility'=>visibility,
          'embargo_release_date'=>(Date.try(:edtf, embargo_release_date) || embargo_release_date).to_s,
          'visibility_during_embargo'=>visibility_during_embargo,
          'visibility_after_embargo'=>visibility_after_embargo,
          'admin_set_id'=>(AdminSet.where(title: @admin_set).first || AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first).id
      }

      if contained_files
        { resource: work_record(work_attributes), files: file_full }
      else
        resource = Hash.new(0)
        resource[:creator] = work_attributes['creator']
        { resource: file_record(work_attributes, resource), files: file_full }
      end

    end

    def work_record(work_attributes)
      resource = @work_type.singularize.classify.constantize.new
      resource.creator = work_attributes['creator']
      resource.depositor = DEPOSITOR_EMAIL
      resource.save

      resource.label = work_attributes['title']
      resource.title = [work_attributes['title']]
      resource.keyword =  work_attributes['keyword']
      resource.date_created = work_attributes['date_created']
      resource.date_modified = work_attributes['date_modified']
      resource.contributor = work_attributes['contributor']
      resource.description = work_attributes['description']
      resource.identifier = work_attributes['identifier']
      resource.related_url = work_attributes['related_url']
      resource.publisher = work_attributes['publisher']
      resource.subject = work_attributes['subjects']
      resource.resource_type = work_attributes['resource_type']
      resource.language = work_attributes['language']
      resource.rights_statement = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
      resource.visibility = work_attributes['visibility']
      unless work_attributes['embargo_release_date'].blank?
      resource.embargo_release_date = work_attributes['embargo_release_date']
      resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
      resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
      end
      resource.admin_set_id = work_attributes['admin_set_id']

      resource
    end

    def file_record(work_attributes, resource)
      resource[:label] = work_attributes['title']
      resource[:title] = [work_attributes['title']]
      resource[:keyword] =  work_attributes['keyword']
      resource[:date_created] = work_attributes['date_created']
      resource[:date_modified] = work_attributes['date_modified']
      resource[:contributor] = work_attributes['contributor']
      resource[:description] = work_attributes['description']
      resource[:identifier] = work_attributes['identifier']
      resource[:related_url] = work_attributes['related_url']
      resource[:publisher] = work_attributes['publisher']
      resource[:subject] = work_attributes['subjects']
      resource[:resource_type] = work_attributes['resource_type']
      resource[:language] = work_attributes['language']
      resource[:rights_statement] = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
      resource[:visibility] = work_attributes['visibility']
      unless work_attributes['embargo_release_date'].blank?
        resource[:embargo_release_date] = work_attributes['embargo_release_date']
        resource[:visibility_during_embargo] = work_attributes['visibility_during_embargo']
        resource[:visibility_after_embargo] = work_attributes['visibility_after_embargo']
      end

      resource
    end
  end
end