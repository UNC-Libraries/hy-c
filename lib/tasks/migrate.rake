namespace :cdr do
  # coding: utf-8
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'
  require 'yaml'

  # Must include the email address of a valid user in order to ingest files
  DEPOSITOR_EMAIL = 'admin@example.com'

  # Sample data is currently stored in the hyrax/lib/tasks/migration/tmp directory.  Each object is stored in a
  # directory labelled with its uuid. Container objects only contain a metadata file and are stored as
  # {uuid}/uuid:{uuid}-object.xml. File objects contain a metadata file and the file to be imported which are stored in
  # the same directory as {uuid}/uuid:{uuid}.xml and {uuid}/{uuid}-DATA_FILE.*, respectively.

  namespace :migration do

    desc 'batch migrate generic files from FOXML file'
    task :items, [:collection, :mapping_file] => :environment do |t, args|
      config = YAML.load_file('lib/tasks/migration_config.yml')
      collection_config = config[args[:collection]]
      @work_type = collection_config['work_type']
      @admin_set = collection_config['admin_set']

      # Hash of all binaries in storage directory
      @binary_hash = Hash.new
      File.open(collection_config['binaries']) do |file|
        file.each do |line|
          value = line.strip
          key = get_uuid_from_path(value)
          @binary_hash[key] = value
        end
      end

      # Hash of all .xml objects in storage directory
      @object_hash = Hash.new
      File.open(collection_config['objects']) do |file|
        file.each do |line|
          value = line.strip
          key = get_uuid_from_path(value)
          @object_hash[key] = value
        end
      end

      # Create file mapping new and old ids
      @csv_output = args[:mapping_file]
      if !File.exist?(@csv_output)
        @csv_output = File.new(@csv_output, 'w')
      end

      collection_ids_file = collection_config['collection_list']
      migrate_objects(collection_ids_file)
    end

    def migrate_objects(collection_ids_file)
      collection_uuids = Array.new
      CSV.open(collection_ids_file) do |file|
        file.each do |line|
          collection_uuids.append(line[0].strip)
        end
      end

      puts 'Object count: '+collection_uuids.count.to_s

      collection_uuids.each do |collection_uuid|
        uuid = get_uuid_from_path(collection_uuid)
        # Assuming uuid for metadata and binary are the same
        # Skip file/binary metadata
        # solr returns column header; skip that, too
        if @binary_hash[uuid].blank? && !uuid.blank?
          metadata_fields = metadata(@object_hash[uuid])

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
        # Get file/binary object metadata
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
        csv << [get_uuid_from_path(f), file_set.id]
      end

      file_set
    end
    
    def metadata(file)
      metadata = Nokogiri::XML(File.open(file))

      #get the uuid of the object
      uuid = get_uuid_from_path(metadata.at_xpath('foxml:digitalObject/@PID', MigrationConstants::NS).value)
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

      # TODO: add all generic work attributes
      title = mods_version.xpath('mods:titleInfo/mods:title', MigrationConstants::NS).text
      alternative_title = mods_version.xpath("mods:titleInfo[contains(@type, 'alternative')]/mods:title", MigrationConstants::NS).text
      creator = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[@roleTerm='Creator']", MigrationConstants::NS)
      contributor = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Contributor')]", MigrationConstants::NS)
      advisor = mods_version.xpath('mods:namemods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Thesis advisor')]", MigrationConstants::NS)
      funder = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name[contains(@type, 'corporate')]/mods:namePart/mods:role[contains(@roleTerm, 'Funder')]", MigrationConstants::NS)
      project_director = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Project director')]", MigrationConstants::NS)
      researcher = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Researcher')]", MigrationConstants::NS)
      sponsor = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Sponsor')]", MigrationConstants::NS)
      translator = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Translator')]", MigrationConstants::NS)
      reviewer = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Reviewer')]", MigrationConstants::NS)
      composer = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Composer')]", MigrationConstants::NS)
      arranger = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name/mods:namePart/mods:role[contains(@roleTerm, 'Arranger')]", MigrationConstants::NS)
      degree_granting_institution = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name[contains(@type, 'corporate')]/mods:namePart/mods:role[contains(@roleTerm, 'Degree granting institution')]", MigrationConstants::NS)
      conference_name = mods_version.xpath('mods:name/mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath("mods:name[@displayLabel='Conference' and @type='conference']", MigrationConstants::NS)
      date_issued = mods_version.xpath('mods:originInfo/mods:dateIssued', MigrationConstants::NS).text
      date_created = mods_version.xpath('mods:originInfo/mods:dateCreated', MigrationConstants::NS).text
      copyright_date = mods_version.xpath('mods:originInfo/mods:copyrightDate', MigrationConstants::NS).text
      last_date_modified = mods_version.xpath('mods:originInfo[@displayLabel="Last Date Modified"]/mods:dateModified', MigrationConstants::NS).text
      date_other = mods_version.xpath('mods:originInfo/mods:dateOther', MigrationConstants::NS).text
      date_captured = mods_version.xpath('mods:originInfo/mods:dateCaptured', MigrationConstants::NS).text
      graduation_year = mods_version.xpath('mods:originInfo[@displayLabel="Date Graduated"]/mods:dateOther', MigrationConstants::NS).text
      abstract = mods_version.xpath('mods:abstract', MigrationConstants::NS).text
      note = mods_version.xpath('mods:note', MigrationConstants::NS).map(&:text)
      description = mods_version.xpath('mods:note[@displayLabel="Description" or @displayLabel="Methods"]', MigrationConstants::NS).map(&:text)
      extent = mods_version.xpath('mods:physicalDescription/mods:extent', MigrationConstants::NS).map(&:text)
      table_of_contents = mods_version.xpath('mods:tableOfContents', MigrationConstants::NS).map(&:text)
      citation = mods_version.xpath('mods:note[@type="citation/reference"]', MigrationConstants::NS).map(&:text)
      edition = mods_version.xpath('mods:originInfo/mods:edition', MigrationConstants::NS).map(&:text)
      peer_review_status = mods_version.xpath('mods:genre[@authority="local"]', MigrationConstants::NS).map(&:text)
      degree = mods_version.xpath('mods:note[@displayLabel="Degree"]', MigrationConstants::NS).map(&:text)
      academic_concentration = mods_version.xpath('mods:note[@displayLabel="Academic concentration"]', MigrationConstants::NS).map(&:text)
      discipline = mods_version.xpath('mods:note[@displayLabel="Thesis degree discipline"]', MigrationConstants::NS).map(&:text)
      award = mods_version.xpath('mods:note[@displayLabel="Honors Level"]', MigrationConstants::NS).map(&:text)
      medium = mods_version.xpath('mods:physicalDescription/mods:form', MigrationConstants::NS).map(&:text)
      kind_of_data = mods_version.xpath('mods:genre[@authority="ddi"]', MigrationConstants::NS).map(&:text)
      series = mods_version.xpath('mods:relatedItem[@type="series"]', MigrationConstants::NS).map(&:text)
      subject = mods_version.xpath('mods:subject/mods:topic', MigrationConstants::NS).map(&:text)
      keywords = mods_version.xpath('mods:note/mods:geographic/@valueURI', MigrationConstants::NS).map(&:text)
      language = mods_version.xpath('mods:language/mods:languageTerm',MigrationConstants::NS).text
      resource_type = mods_version.xpath('mods:language/mods:languageTerm',MigrationConstants::NS).text


      rdf_version = metadata.xpath("//foxml:xmlContent//rdf:RDF", MigrationConstants::NS).last
      if rdf_version.to_s.match(/contains/)
        contained_files = rdf_version.xpath("rdf:Description/*[local-name() = 'contains']/@rdf:resource", MigrationConstants::NS)
        contained_files.each do |contained_file|
          tmp_uuid = get_uuid_from_path(contained_file.to_s)
          file_full << @object_hash[tmp_uuid]
        end

        if file_full.count > 1
          representative = rdf_version.xpath('rdf:Description/*[local-name() = "defaultWebObject"]/@rdf:resource', MigrationConstants::NS).to_s.split('/')[1]
          if representative
            representative = @object_hash[get_uuid_from_path(representative)]
            file_full -= [representative]
            file_full = [representative] + file_full
          end
        end
      end

      # creators = mods_version.xpath('mods:name//mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath('mods:name//mods:namePart', MigrationConstants::NS)
      # contributors = mods_version.xpath('mods:name//mods:namePart', MigrationConstants::NS).map(&:text) if mods_version.xpath('mods:name//mods:namePart',MigrationConstants::NS)
      # keywords = mods_version.xpath("mods:note[contains(@displayLabel, 'Keywords')]", MigrationConstants::NS).map(&:text)
      # keywords.uniq!
      #
      # # original_filename = file_version.attribute('LABEL').to_s
      # subjects = mods_version.xpath('mods:subject',MigrationConstants::NS).map(&:text)
      # description = mods_version.xpath('mods:abstract',MigrationConstants::NS).text.gsub(/\n/,' ').gsub(/\t/,' ')
      # description = HTMLEntities.new.decode description
      # date = mods_version.xpath('mods:dateCreate',MigrationConstants::NS).text
      # identifier = mods_version.xpath('mods:identifier',MigrationConstants::NS).map(&:text)
      # related_url = mods_version.xpath('mods:location//mods:url', MigrationConstants::NS).map(&:text)
      # resource_type = mods_version.xpath('mods:genre', MigrationConstants::NS).text.strip
      #
      # if resource_type == 'Journal Article'
      #   resource_type = 'Article'
      # end
      #
      # publisher = mods_version.xpath('mods:originInfo//mods:publisher',MigrationConstants::NS).text

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
          'title'=>[title],
          'label'=>title,
          'contributor'=>contributor,
          'creator'=>creator,
          'date_created'=>[(Date.try(:edtf, date_created) || date_created).to_s],
          'date_modified'=>(Date.try(:edtf, date_modified) || date_modified).to_s,
          'description'=>[description],
          'identifier'=>identifier,
          'keyword'=>keywords,
          'language'=>[language],
          'license'=>nil,
          'publisher'=>[publisher],
          'related_url' => related_url,
          'resource_type'=>[resource_type],
          'rights_statement'=>nil,
          'subject'=>subjects,
          'abstract'=>abstract,
          'academic_concentration'=>nil,
          'access'=>nil,
          'advisor'=>advisor,
          'alternative_title'=>alternative_title,
          'arranger'=>arranger,
          'award'=>nil,
          'bibliographic_citation'=>citation,
          'composer'=>composer,
          'conference_name'=>conference_name,
          'copyright_date'=>copyright_date,
          'date_captured'=>date_captured,
          'date_issued'=>date_issued,
          'date_other'=>date_other,
          'degree'=>nil,
          'degree_granting_institution'=>degree_granting_institution,
          'digital_collection'=>nil,
          'discipline'=>nil,
          'doi'=>nil,
          'edition'=>edition,
          'extent'=>extent,
          'funder'=>funder,
          'genre'=>nil,
          'geographic_subject'=>nil,
          'graduation_year'=>graduation_year,
          'isbn'=>nil,
          'issn'=>nil,
          'journal_issue'=>nil,
          'journal_title'=>nil,
          'journal_volume'=>nil,
          'kind_of_data'=>nil,
          'last_modified_date'=>last_date_modified,
          'medium'=>nil,
          'note'=>note,
          'page_end'=>nil,
          'page_start'=>nil,
          'peer_review_status'=>peer_review_status,
          'place_of_publication'=>nil,
          'project_director'=>project_director,
          'researcher'=>researcher,
          'reviewer'=>reviewer,
          'rights_holder'=>nil,
          'series'=>nil,
          'sponsor'=>sponsor,
          'table_of_contents'=>table_of_contents,
          'translator'=>translator,
          'url'=>nil,
          'use'=>nil,
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

        { resource: file_record(work_attributes, resource), files: file_full }
      end

    end

    def work_record(work_attributes)
      resource = @work_type.singularize.classify.constantize.new
      resource.creator = work_attributes['creator']
      resource.depositor = DEPOSITOR_EMAIL
      resource.save

      resource.attributes = work_attributes.reject{|k,v| !resource.attributes.keys.member?(k.to_s)}

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

    # FileSets can include any metadata listed in BasicMetadata file
    def file_record(work_attributes, resource)
      resource[:creator] = work_attributes['creator']
      resource[:depositor] = DEPOSITOR_EMAIL
      resource[:label] = work_attributes['label']
      resource[:title] = work_attributes['title']
      resource[:bibliographic_citation] =  work_attributes['bibliographic_citation']
      resource[:keyword] =  work_attributes['keyword']
      resource[:date_created] = work_attributes['date_created']
      resource[:date_modified] = work_attributes['date_modified']
      resource[:date_uploaded] = work_attributes['date_uploaded']
      resource[:contributor] = work_attributes['contributor']
      resource[:description] = work_attributes['description']
      resource[:identifier] = work_attributes['identifier']
      resource[:related_url] = work_attributes['related_url']
      resource[:publisher] = work_attributes['publisher']
      resource[:subject] = work_attributes['subjects']
      resource[:resource_type] = work_attributes['resource_type']
      resource[:language] = work_attributes['language']
      resource[:based_near] = work_attributes['based_near']
      resource[:source] = work_attributes['source']
      resource[:license] = work_attributes['license']
      resource[:rights_statement] = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
      resource[:visibility] = work_attributes['visibility']
      unless work_attributes['embargo_release_date'].blank?
        resource[:embargo_release_date] = work_attributes['embargo_release_date']
        resource[:visibility_during_embargo] = work_attributes['visibility_during_embargo']
        resource[:visibility_after_embargo] = work_attributes['visibility_after_embargo']
      end

      resource
    end

    def get_uuid_from_path(path)
      path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
    end
  end
end