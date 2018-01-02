namespace :cdr do
  # coding: utf-8
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'

  #set fedora access URL. replace with fedora username and password
  #test environment will not have access to ERA's fedora

  # Must include the email address of a valid user in order to ingest files
  DEPOSITOR_EMAIL = 'admin@example.com'

  #Use the ERA public interface to download original file and foxml
  FEDORA_URL = ENV['FEDORA_PRODUCTION_URL']

  #temporary location for file download
  TEMP = 'lib/tasks/migration/tmp'
  FILE_STORE = 'lib/tasks/migration/files'
  TEMP_FOXML = 'lib/tasks/migration/tmp'
  FileUtils::mkdir_p TEMP

  #report directory
  REPORTS = 'lib/tasks/migration/reports/'
  #Oddities report
  ODDITIES = REPORTS+ 'oddities.txt'
  #verification error report
  VERIFICATION_ERROR = REPORTS + 'verification_errors.txt'
  #item migration list
  ITEM_LIST = REPORTS + 'item_list.txt'
  #collection list
  COLLECTION_LIST = REPORTS + 'collection_list.txt'
  FileUtils::mkdir_p REPORTS
  #successful_path
  COMPLETED_DIR = 'lib/tasks/migration/completed'
  FileUtils::mkdir_p COMPLETED_DIR

  # Sample data is currently stored in the hyrax/lib/tasks/migration/tmp directory.  Each object is stored in a
  # directory labelled with its uuid. Container objects only contain a metadata file and are stored as
  # {uuid}/uuid:{uuid}-object.xml. File objects contain a metadata file and the file to be imported which are stored in
  # the same directory as {uuid}/uuid:{uuid}.xml and {uuid}/{uuid}-DATA_FILE.*, respectively.

  namespace :migration do

    desc 'batch migrate generic files from FOXML file'
    task :items, [:dir, :migrate_datastreams] => :environment do |t, args|
      args.with_defaults(:migrate_datastreams => "true")

      metadata_dir = args.dir
      migrate_objects(metadata_dir)
    end

    def migrate_objects(metadata_dir)
      metadata_files = Dir.glob("#{metadata_dir}/**/*-object.xml")

      puts 'Object count: '+metadata_files.count.to_s

      metadata_files.sort.each do |file|
        uuid = file.split(metadata_dir)[1].split('/')[1]
        if Dir.glob("#{metadata_dir}/#{uuid}/#{uuid}-DATA_FILE.*").blank?
          metadata_fields = metadata(file, metadata_dir)

          puts 'Number of files: '+metadata_fields[:files].count.to_s

          if metadata_fields[:files][0].match(/.+\.xml/)
            resource = metadata_fields[:resource]
            resource.save!

            ingest_files(resource: resource, files: metadata_fields[:files], metadata_dir: metadata_dir)
          end
        end
      end
    end
   
    def ingest_files(parent: nil, resource: nil, files: [], metadata_dir: nil)
      ordered_members = []

      files.each do |f|
        file_metadata = metadata(f, metadata_dir)
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

      file_set
    end
    
    def metadata(file, metadata_dir)
      metadata = Nokogiri::XML(File.open(file))

      #get the uuid of the object
      uuid = metadata.at_xpath('foxml:digitalObject/@PID', MigrationConstants::NS).value
      puts 'getting metadata for: '+uuid
      uuid_dir_name = uuid.split(':')[1]

      file_full = Array.new(0)
      representative = ''
      visibility_during_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      visibility_after_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      embargo_release_date = ''
      visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      file_name = Dir.glob("#{metadata_dir}/#{uuid_dir_name}/#{uuid_dir_name}-DATA_FILE.*")
      if file_name.count == 1
        file_full << file_name.first
      elsif file_name.count > 1
        puts 'FAIL #1'
        MigrationLogger.fatal 'Too many files linked to object'
        return
      end

      #get the date_created
      date_created_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'model#createdDate')]/@VALUE", MigrationConstants::NS).to_s
      date_created = DateTime.strptime(date_created_string, '%Y-%m-%dT%H:%M:%S.%N%Z') unless date_created_string.nil?
      #get the modifiedDate
      date_modified_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'view#lastModifiedDate')]/@VALUE", MigrationConstants::NS).to_s
      date_modified = DateTime.strptime(date_modified_string, '%Y-%m-%dT%H:%M:%S.%N%Z') unless date_modified_string.nil?
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
          tmp_uuid = contained_file.to_s.split('fedora/')[1]
          file_full << metadata_dir+'/'+tmp_uuid.split(':')[1]+'/'+tmp_uuid+'-object.xml'
        end

        if file_full.count > 1
          representative = rdf_version.xpath('rdf:Description/*[local-name() = "defaultWebObject"]/@rdf:resource', MigrationConstants::NS).to_s.split('/')[1]
          if representative
            representative = metadata_dir+'/'+representative.split(':')[1]+'/'+representative+'-object.xml'
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
          'date_created'=>date_created,
          'keyword'=>keywords,
          'date_modified'=>date_modified,
          'contributor'=>contributors,
          'description'=>[description],
          'identifier'=>identifier,
          'related_url' => related_url,
          'publisher'=>[publisher],
          'subject'=>subjects,
          'resource_type'=>[resource_type],
          'language'=>[language],
          'visibility'=>visibility,
          'embargo_release_date'=>embargo_release_date,
          'visibility_during_embargo'=>visibility_during_embargo,
          'visibility_after_embargo'=>visibility_after_embargo
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
      resource = Work.new
      resource.creator = work_attributes['creator']
      resource.depositor = DEPOSITOR_EMAIL
      resource.save

      resource.label = work_attributes['title']
      resource.title = [work_attributes['title']]
      resource.keyword =  work_attributes['keyword']
      resource.date_created = work_attributes['date_created']
      resource.date_modified = work_attributes['date_modified']
      resource.keyword = work_attributes['keyword']
      resource.contributor = work_attributes['contributor']
      resource.description = work_attributes['description']
      resource.identifier = work_attributes['identifier']
      resource.related_url = work_attributes['related_url']
      resource.publisher = work_attributes['publisher']
      resource.subject = work_attributes['subjects']
      resource.resource_type = work_attributes['resource_type']
      resource.language = work_attributes['language']
      resource.rights_statement = ['http://www.europeana.eu/portal/rights/rr-r.html']
      resource.visibility = work_attributes['visibility']
      unless work_attributes['embargo_release_date'].blank?
      resource.embargo_release_date = work_attributes['embargo_release_date']
      resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
      resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
      end

      resource
    end

    def file_record(work_attributes, resource)
      resource[:label] = work_attributes['title']
      resource[:title] = [work_attributes['title']]
      resource[:keyword] =  work_attributes['keyword']
      resource[:date_created] = work_attributes['date_created']
      resource[:date_modified] = work_attributes['date_modified']
      resource[:keyword] = work_attributes['keyword']
      resource[:contributor] = work_attributes['contributor']
      resource[:description] = work_attributes['description']
      resource[:identifier] = work_attributes['identifier']
      resource[:related_url] = work_attributes['related_url']
      resource[:publisher] = work_attributes['publisher']
      resource[:subject] = work_attributes['subjects']
      resource[:resource_type] = work_attributes['resource_type']
      resource[:language] = work_attributes['language']
      resource[:rights_statement] = ['http://www.europeana.eu/portal/rights/rr-r.html']
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