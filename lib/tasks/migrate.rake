namespace :cdr do
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'
  require 'yaml'

  namespace :migration do

    desc 'batch migrate generic files from FOXML file'
    task :items, [:collection, :configuration_file, :mapping_file] => :environment do |t, args|
      if AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).count != 0
        config = YAML.load_file(args[:configuration_file])
        collection_config = config[args[:collection]]
        @work_type = collection_config['work_type']
        @admin_set = collection_config['admin_set']
        @depositor_key = User.where(email: collection_config['depositor_email']).first.uid
        @collection_name = collection_config['collection_name']
        @child_work_type = collection_config['child_work_type']

        # Store parent-child relationships
        @parent_hash = Hash.new
        # Store uuid/hyrax-id mappings for current collection
        @mapping = Hash.new

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
        if !@child_work_type.blank?
          attach_children
        end
      else
        puts 'The default admin set does not exist'
      end
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

          resource = metadata_fields[:resource]
          resource.save!

          @mapping[uuid] = resource.id

          # Record old and new ids for works
          CSV.open(@csv_output, 'a+') do |csv|
            csv << [uuid, resource.id]
          end

          if !metadata_fields[:files].blank? && metadata_fields[:files][0].match(/.+\.xml/)
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
      actor = Hyrax::Actors::FileSetActor.new(file_set, User.find_by_user_key(@depositor_key))
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

      # get the uuid of the object
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

      title = mods_version.xpath('mods:titleInfo/mods:title', MigrationConstants::NS).map(&:text)
      alternative_title = mods_version.xpath("mods:titleInfo[@type='alternative']/mods:title", MigrationConstants::NS).map(&:text)
      creator_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Creator"]', MigrationConstants::NS)
      creator = []
      creator_node.each do |node|
        creator << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      contributor_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Contributor"]', MigrationConstants::NS)
      contributor = []
      contributor_node.each do |node|
        contributor << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      advisor_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Thesis advisor"]', MigrationConstants::NS)
      advisor = []
      advisor_node.each do |node|
        advisor << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      funder_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Funder"]', MigrationConstants::NS)
      funder = []
      funder_node.each do |node|
        funder << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      project_director_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Project director"]', MigrationConstants::NS)
      project_director = []
      project_director_node.each do |node|
        project_director << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      researcher_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Researcher"]', MigrationConstants::NS)
      researcher = []
      researcher_node.each do |node|
        researcher << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      sponsor_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Sponsor"]', MigrationConstants::NS)
      sponsor = []
      sponsor_node.each do |node|
        sponsor << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      translator_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Translator"]', MigrationConstants::NS)
      translator = []
      translator_node.each do |node|
        translator << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      reviewer_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Reviewer"]', MigrationConstants::NS)
      reviewer = []
      reviewer_node.each do |node|
        reviewer << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      composer_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Composer"]', MigrationConstants::NS)
      composer = []
      composer_node.each do |node|
        composer << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      arranger_node = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Arranger"]', MigrationConstants::NS)
      arranger = []
      arranger_node.each do |node|
        arranger << node.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
      end
      degree_granting_institution = mods_version.xpath('mods:name[mods:role/mods:roleTerm/text()="Degree granting institution"]/mods:namePart', MigrationConstants::NS).map(&:text)
      conference_name = mods_version.xpath('mods:name[@displayLabel="Conference" and @type="conference"]/mods:namePart', MigrationConstants::NS).map(&:text)
      orcid = mods_version.xpath('mods:name/mods:identifier', MigrationConstants::NS).map(&:text)
      affiliation = mods_version.xpath('mods:name/mods:affiliation', MigrationConstants::NS).map(&:text)
      other_affiliation = mods_version.xpath('mods:name/mods:description', MigrationConstants::NS).map(&:text)
      date_issued = mods_version.xpath('mods:originInfo/mods:dateIssued', MigrationConstants::NS).map(&:text)
      copyright_date = mods_version.xpath('mods:originInfo/mods:copyrightDate', MigrationConstants::NS).map(&:text)
      last_date_modified = mods_version.xpath('mods:originInfo[@displayLabel="Last Date Modified"]/mods:dateModified', MigrationConstants::NS).map(&:text)
      date_other = mods_version.xpath('mods:originInfo/mods:dateOther', MigrationConstants::NS).map(&:text)
      date_captured = mods_version.xpath('mods:originInfo/mods:dateCaptured', MigrationConstants::NS).map(&:text)
      graduation_year = mods_version.xpath('mods:originInfo[@displayLabel="Date Graduated"]/mods:dateOther', MigrationConstants::NS).map(&:text)
      abstract = mods_version.xpath('mods:abstract', MigrationConstants::NS).map(&:text)
      note = mods_version.xpath('mods:note', MigrationConstants::NS).map(&:text)
      description = mods_version.xpath('mods:note[@displayLabel="Description" or @displayLabel="Methods"]', MigrationConstants::NS).map(&:text)
      extent = mods_version.xpath('mods:physicalDescription/mods:extent', MigrationConstants::NS).map(&:text)
      table_of_contents = mods_version.xpath('mods:tableOfContents', MigrationConstants::NS).map(&:text)
      citation = mods_version.xpath('mods:note[@type="citation/reference"]', MigrationConstants::NS).map(&:text)
      edition = mods_version.xpath('mods:originInfo/mods:edition', MigrationConstants::NS).map(&:text)
      peer_review_status = mods_version.xpath('mods:genre[@authority="local"]', MigrationConstants::NS).map(&:text)
      degree = mods_version.xpath('mods:note[@displayLabel="Degree"]', MigrationConstants::NS).map(&:text)
      academic_concentration = mods_version.xpath('mods:note[@displayLabel="Academic concentration"]', MigrationConstants::NS).map(&:text)
      award = mods_version.xpath('mods:note[@displayLabel="Honors Level"]', MigrationConstants::NS).map(&:text)
      medium = mods_version.xpath('mods:physicalDescription/mods:form', MigrationConstants::NS).map(&:text)
      kind_of_data = mods_version.xpath('mods:genre[@authority="ddi"]', MigrationConstants::NS).map(&:text)
      series = mods_version.xpath('mods:relatedItem[@type="series"]', MigrationConstants::NS).map(&:text)
      subject = mods_version.xpath('mods:subject/mods:topic', MigrationConstants::NS).map(&:text)
      geographic_subject = mods_version.xpath('mods:subject/mods:geographic/@valueURI', MigrationConstants::NS).map(&:text)
      keywords = mods_version.xpath('mods:note[@displayLabel="Keywords"]', MigrationConstants::NS).map(&:text)
      language = mods_version.xpath('mods:language/mods:languageTerm',MigrationConstants::NS).map(&:text)
      resource_type = mods_version.xpath('mods:genre',MigrationConstants::NS).map(&:text)
      dcmi_type = mods_version.xpath('mods:typeOfResource/@valueURI',MigrationConstants::NS).map(&:text)
      use = mods_version.xpath('mods:accessCondition[@type="use and reproduction" and @displayLabel!="License" and @displayLabel!="Rights Statement"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
      license = mods_version.xpath('mods:accessCondition[@displayLabel="License" and @type="use and reproduction"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
      rights_statement = mods_version.xpath('mods:accessCondition[@displayLabel="Rights Statement" and @type="use and reproduction"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
      rights_holder = mods_version.xpath('mods:accessCondition/rights:copyright/rights:rights.holder/rights:name',MigrationConstants::NS).map(&:text)
      access = mods_version.xpath('mods:accessCondition[@type="restriction on access"]',MigrationConstants::NS).map(&:text)
      doi = mods_version.xpath('mods:identifier[@type="doi"]',MigrationConstants::NS).map(&:text)
      identifier = mods_version.xpath('mods:identifier[@type="pdf"]/identifier[@type="pmpid"]',MigrationConstants::NS).map(&:text)
      isbn = mods_version.xpath('mods:identifier[@type="isbn"]',MigrationConstants::NS).map(&:text)
      issn = mods_version.xpath('mods:relatedItem/mods:identifier[@type="issn"]',MigrationConstants::NS).map(&:text)
      publisher = mods_version.xpath('mods:originInfo/mods:publisher',MigrationConstants::NS).map(&:text)
      place_of_publication = mods_version.xpath('mods:originInfo/mods:place/mods:placeTerm',MigrationConstants::NS).map(&:text)
      journal_title = mods_version.xpath('mods:relatedItem[@type="host"]/mods:titleInfo/mods:title',MigrationConstants::NS).map(&:text)
      journal_volume = mods_version.xpath('mods:relatedItem[@type="host"]/mods:part/mods:detail[@type="volume"]/mods:number',MigrationConstants::NS).map(&:text)
      journal_issue = mods_version.xpath('mods:relatedItem[@type="host"]/mods:part/mods:detail[@type="issue"]/mods:number',MigrationConstants::NS).map(&:text)
      start_page = mods_version.xpath('mods:relatedItem[@type="host"]/mods:part/mods:extent[@type="page"]/mods:start',MigrationConstants::NS).map(&:text)
      end_page = mods_version.xpath('mods:relatedItem[@type="host"]/mods:part/mods:extent[@type="page"]/mods:end',MigrationConstants::NS).map(&:text)
      related_url = mods_version.xpath('mods:relatedItem/mods:location/mods:url',MigrationConstants::NS).map(&:text)
      url = mods_version.xpath('mods:location/mods:url',MigrationConstants::NS).map(&:text)
      publisher_version = mods_version.xpath('mods:location/mods:url[@displayLabel="Publisher Version"] | mods:relatedItem[@type="otherVersion"]/mods:location',MigrationConstants::NS).map(&:text)
      digital_collection = mods_version.xpath('mods:relatedItem[@displayLabel="Collection" and @type="host"]/mods:titleInfo/mods:title',MigrationConstants::NS).map(&:text)


      deposit_record = ''
      cdr_model_type = ''
      rdf_version = metadata.xpath("//rdf:RDF", MigrationConstants::NS).last
      if rdf_version
        if rdf_version.to_s.match(/originalDeposit/)
          deposit_record = rdf_version.xpath('rdf:Description/*[local-name() = "originalDeposit"]/@rdf:resource', MigrationConstants::NS).map(&:text)
        end

        if rdf_version.to_s.match(/hasModel/)
          cdr_model_type = rdf_version.xpath('rdf:Description/*[local-name() = "hasModel"]/@rdf:resource', MigrationConstants::NS).map(&:text)
          cdr_model_type = (cdr_model_type.include? 'info:fedora/cdr-model:AggregateWork') ? 'aggregate' : ''
        end

        if cdr_model_type == 'aggregate'
          @parent_hash[uuid] = Array.new
        end

        if rdf_version.to_s.match(/contains/)
          contained_files = rdf_version.xpath("rdf:Description/*[local-name() = 'contains']/@rdf:resource", MigrationConstants::NS)
          contained_files.each do |contained_file|
            tmp_uuid = get_uuid_from_path(contained_file.to_s)
            if !@binary_hash[tmp_uuid].blank?
              file_full << @object_hash[tmp_uuid]
            else
              @parent_hash[uuid] << tmp_uuid
            end
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
      end

      if !language.blank?
        language.map!{|e| LanguagesService.label("http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}") ?
                              "http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}" : e}
      end

      collection = Collection.where(title: @collection_name).first
      if !@collection_name.blank? && collection.blank?
        user_collection_type = Hyrax::CollectionType.where(title: 'User Collection').first.gid
        collection = Collection.create(title: [@collection_name],
                                       depositor: @depositor_key,
                                       collection_type_gid: user_collection_type)
      end

      work_attributes = {
          'title'=>title,
          'label'=>title,
          'contributor'=>contributor,
          'creator'=>creator,
          'date_created'=>(Date.try(:edtf, date_created) || date_created).to_s,
          'date_modified'=>(Date.try(:edtf, date_modified) || date_modified).to_s,
          'description'=>description,
          'identifier'=>identifier,
          'keyword'=>keywords,
          'language'=>language,
          'license'=>license,
          'publisher'=>publisher,
          'related_url' => related_url,
          'resource_type'=>resource_type,
          'rights_statement'=>rights_statement,
          'subject'=>subject,
          'abstract'=>abstract,
          'academic_concentration'=>academic_concentration,
          'access'=>access,
          'advisor'=>advisor,
          'affiliation'=>affiliation,
          'alternative_title'=>alternative_title,
          'arranger'=>arranger,
          'award'=>award,
          'bibliographic_citation'=>citation,
          'composer'=>composer,
          'conference_name'=>conference_name,
          'copyright_date'=>copyright_date.map{|date| (Date.try(:edtf, date) || date).to_s},
          'date_captured'=>date_captured.map{|date| (Date.try(:edtf, date) || date).to_s},
          'date_issued'=>date_issued.map{|date| (Date.try(:edtf, date) || date).to_s},
          'date_other'=>date_other.map{|date| (Date.try(:edtf, date) || date).to_s},
          'dcmi_type'=>dcmi_type,
          'degree'=>degree,
          'degree_granting_institution'=>degree_granting_institution,
          'deposit_record'=>deposit_record,
          'digital_collection'=>digital_collection,
          'doi'=>doi,
          'edition'=>edition,
          'extent'=>extent,
          'funder'=>funder,
          'geographic_subject'=>geographic_subject,
          'graduation_year'=>graduation_year,
          'isbn'=>isbn,
          'issn'=>issn,
          'journal_issue'=>journal_issue,
          'journal_title'=>journal_title,
          'journal_volume'=>journal_volume,
          'kind_of_data'=>kind_of_data,
          'last_modified_date'=>last_date_modified,
          'medium'=>medium,
          'note'=>note,
          'orcid'=>orcid,
          'other_affiliation'=>other_affiliation,
          'page_end'=>end_page,
          'page_start'=>start_page,
          'peer_review_status'=>peer_review_status,
          'place_of_publication'=>place_of_publication,
          'project_director'=>project_director,
          'publisher_version'=>publisher_version,
          'researcher'=>researcher,
          'reviewer'=>reviewer,
          'rights_holder'=>rights_holder,
          'series'=>series,
          'sponsor'=>sponsor,
          'table_of_contents'=>table_of_contents,
          'translator'=>translator,
          'url'=>url,
          'use'=>use,
          'visibility'=>visibility,
          'embargo_release_date'=>(Date.try(:edtf, embargo_release_date) || embargo_release_date).to_s,
          'visibility_during_embargo'=>visibility_during_embargo,
          'visibility_after_embargo'=>visibility_after_embargo,
          'admin_set_id'=>(AdminSet.where(title: @admin_set).first || AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first).id,
          'member_of_collections'=>[Collection.where(title: @collection_name).first],
          'cdr_model_type'=>cdr_model_type
      }

      work_attributes.reject!{|k,v| v.blank? || v.empty?}

      if contained_files
        { resource: work_record(work_attributes), files: file_full }
      else
        resource = Hash.new(0)

        { resource: file_record(work_attributes, resource), files: file_full }
      end

    end

    def work_record(work_attributes)
      if !@child_work_type.blank? && work_attributes['cdr_model_type'] != 'aggregate'
        resource = @child_work_type.singularize.classify.constantize.new
      else
        resource = @work_type.singularize.classify.constantize.new
      end
      resource.creator = work_attributes['creator']
      resource.depositor = @depositor_key
      resource.save

      # Singularize non-enumerable attributes
      work_attributes.each do |k,v|
        if resource.attributes.keys.member?(k.to_s) && !resource.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
          work_attributes[k] = v.first
        else
          work_attributes[k] = v
        end
      end

      # Only keep attributes which apply to the given work type
      resource.attributes = work_attributes.reject{|k,v| !resource.attributes.keys.member?(k.to_s)}

      resource.rights_statement = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
      resource.visibility = work_attributes['visibility']
      unless work_attributes['embargo_release_date'].blank?
      resource.embargo_release_date = work_attributes['embargo_release_date']
      resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
      resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
      end
      resource.admin_set_id = work_attributes['admin_set_id']
      if !@collection_name.blank? && !work_attributes['member_of_collections'].first.blank?
        resource.member_of_collections = work_attributes['member_of_collections']
      end

      resource
    end

    # FileSets can include any metadata listed in BasicMetadata file
    def file_record(work_attributes, resource)
      file_set = FileSet.new
      # Singularize non-enumerable attributes
      work_attributes.each do |k,v|
        if file_set.attributes.keys.member?(k.to_s) && !file_set.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
          work_attributes[k] = v.first
        else
          work_attributes[k] = v
        end
      end
      resource[:creator] = work_attributes['creator']
      resource[:depositor] = @depositor_key
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
      resource[:rights_statement] = ['rights_statement']
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

    def attach_children
      @parent_hash.each do |parent_id, children|
        hyrax_id = @mapping[parent_id]
        parent = @work_type.singularize.classify.constantize.find(hyrax_id)
        children.each do |child|
          if @mapping[child]
            parent.ordered_members << ActiveFedora::Base.find(@mapping[child])
            parent.members << ActiveFedora::Base.find(@mapping[child])
          end
        end
        parent.save!
      end
    end
  end
end
