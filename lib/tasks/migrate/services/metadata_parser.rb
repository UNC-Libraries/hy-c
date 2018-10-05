module Migrate
  module Services
    class MetadataParser

      def initialize(metadata_file, object_hash, binary_hash, collection_uuids, collection_name, depositor, admin_set)
        @metadata_file = metadata_file
        @object_hash = object_hash
        @binary_hash = binary_hash
        @collection_uuids = collection_uuids
        @collection_name = collection_name
        @depositor = depositor
        @admin_set = admin_set
      end

      def parse
        metadata = Nokogiri::XML(File.open(@metadata_file))

        child_works = Array.new

        # get the uuid of the object
        uuid = get_uuid_from_path(metadata.at_xpath('foxml:digitalObject/@PID', MigrationConstants::NS).value)
        puts "getting metadata for: #{uuid}"

        work_attributes = Hash.new

        work_attributes['contained_files'] = Array.new(0)

        # get the date_created
        date_created_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'model#createdDate')]/@VALUE", MigrationConstants::NS).to_s
        date_created = DateTime.strptime(date_created_string, '%Y-%m-%dT%H:%M:%S.%N%Z').strftime('%Y-%m-%d') unless date_created_string.nil?
        work_attributes['date_created'] = (Date.try(:edtf, date_created) || date_created).to_s
        # get the modifiedDate
        date_modified_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'view#lastModifiedDate')]/@VALUE", MigrationConstants::NS).to_s
        date_modified = DateTime.strptime(date_modified_string, '%Y-%m-%dT%H:%M:%S.%N%Z').strftime('%Y-%m-%d') unless date_modified_string.nil?
        work_attributes['date_modified'] = (Date.try(:edtf, date_modified) || date_modified).to_s

        descriptive_mods = metadata.xpath("//foxml:datastream[contains(@ID, 'MD_DESCRIPTIVE')]//foxml:xmlContent//mods:mods", MigrationConstants::NS).last
        dc_metadata = metadata.xpath("//foxml:datastream[@ID='DC']//oai_dc:dc", MigrationConstants::NS)
        work_attributes['dc_title'] = dc_metadata.xpath('dc:title', MigrationConstants::NS).map(&:text)

        if !descriptive_mods
          puts 'No MODS datastream available'
          work_attributes['title'] = work_attributes['dc_title']
          work_attributes['label'] = work_attributes['dc_title']
        else
          work_attributes['title'] = descriptive_mods.xpath('mods:titleInfo[not(@*)]/mods:title', MigrationConstants::NS).map(&:text)
          work_attributes['label'] = work_attributes['title']
          work_attributes['alternative_title'] = descriptive_mods.xpath("mods:titleInfo[@type='alternative' or @type='translated']/mods:title", MigrationConstants::NS).map(&:text)
          work_attributes['creator'] = parse_names_from_mods(descriptive_mods, 'Creator')
          work_attributes['contributor'] = parse_names_from_mods(descriptive_mods, 'Contributor')
          work_attributes['advisor'] = parse_names_from_mods(descriptive_mods, 'Thesis advisor')
          work_attributes['funder'] = parse_names_from_mods(descriptive_mods, 'Funder')
          work_attributes['project_director'] = parse_names_from_mods(descriptive_mods, 'Project director')
          work_attributes['researcher'] = parse_names_from_mods(descriptive_mods, 'Researcher')
          work_attributes['sponsor'] = parse_names_from_mods(descriptive_mods, 'Sponsor')
          work_attributes['translator'] = parse_names_from_mods(descriptive_mods, 'Translator')
          work_attributes['reviewer'] = parse_names_from_mods(descriptive_mods, 'Reviewer')
          work_attributes['composer'] = parse_names_from_mods(descriptive_mods, 'Composer')
          work_attributes['arranger'] = parse_names_from_mods(descriptive_mods, 'Arranger')
          work_attributes['degree_granting_institution'] = parse_names_from_mods(descriptive_mods, 'Degree granting institution')
          work_attributes['conference_name'] = descriptive_mods.xpath('mods:name[@displayLabel="Conference" and @type="conference"]/mods:namePart', MigrationConstants::NS).map(&:text)
          work_attributes['orcid'] = descriptive_mods.xpath('mods:name/mods:nameIdentifier[@type="orcid"]', MigrationConstants::NS).map(&:text)
          work_attributes['affiliation'] = descriptive_mods.xpath('mods:name/mods:affiliation', MigrationConstants::NS).map(&:text)
          work_attributes['affiliation_label'] = work_attributes['affiliation']
          work_attributes['other_affiliation'] = descriptive_mods.xpath('mods:name/mods:description', MigrationConstants::NS).map(&:text)
          date_issued = descriptive_mods.xpath('mods:originInfo/mods:dateIssued', MigrationConstants::NS).map(&:text)
          work_attributes['date_issued'] = date_issued.map{|date| (Date.try(:edtf, date) || date).to_s}
          copyright_date = descriptive_mods.xpath('mods:originInfo/mods:copyrightDate', MigrationConstants::NS).map(&:text)
          work_attributes['copyright_date'] = copyright_date.map{|date| (Date.try(:edtf, date) || date).to_s}
          work_attributes['last_modified_date'] = descriptive_mods.xpath('mods:originInfo[@displayLabel="Last Date Modified"]/mods:dateModified', MigrationConstants::NS).map(&:text)
          date_other = descriptive_mods.xpath('mods:originInfo/mods:dateOther', MigrationConstants::NS).map(&:text)
          work_attributes['date_other'] = date_other.map{|date| (Date.try(:edtf, date) || date).to_s}
          date_captured = descriptive_mods.xpath('mods:originInfo/mods:dateCaptured', MigrationConstants::NS).map(&:text)
          work_attributes['date_captured'] = date_captured.map{|date| (Date.try(:edtf, date) || date).to_s}
          work_attributes['graduation_year'] = descriptive_mods.xpath('mods:originInfo[@displayLabel="Date Graduated"]/mods:dateOther', MigrationConstants::NS).map(&:text)
          work_attributes['abstract'] = descriptive_mods.xpath('mods:abstract', MigrationConstants::NS).map(&:text)
          work_attributes['note'] = descriptive_mods.xpath('mods:note', MigrationConstants::NS).map(&:text)
          work_attributes['description'] = descriptive_mods.xpath('mods:note[@displayLabel="Description" or @displayLabel="Methods"]', MigrationConstants::NS).map(&:text)
          work_attributes['extent'] = descriptive_mods.xpath('mods:physicalDescription/mods:extent', MigrationConstants::NS).map(&:text)
          work_attributes['table_of_contents'] = descriptive_mods.xpath('mods:tableOfContents', MigrationConstants::NS).map(&:text)
          work_attributes['bibliographic_citation'] = descriptive_mods.xpath('mods:note[@type="citation/reference"]', MigrationConstants::NS).map(&:text)
          work_attributes['edition'] = descriptive_mods.xpath('mods:originInfo/mods:edition', MigrationConstants::NS).map(&:text)
          work_attributes['peer_review_status'] = descriptive_mods.xpath('mods:genre[@authority="local"]', MigrationConstants::NS).map(&:text)
          work_attributes['degree'] = descriptive_mods.xpath('mods:note[@displayLabel="Degree"]', MigrationConstants::NS).map(&:text)
          work_attributes['academic_concentration'] = descriptive_mods.xpath('mods:note[@displayLabel="Academic concentration"]', MigrationConstants::NS).map(&:text)
          work_attributes['award'] = descriptive_mods.xpath('mods:note[@displayLabel="Honors Level"]', MigrationConstants::NS).map(&:text)
          work_attributes['medium'] = descriptive_mods.xpath('mods:physicalDescription/mods:form', MigrationConstants::NS).map(&:text)
          work_attributes['kind_of_data'] = descriptive_mods.xpath('mods:genre[@authority="ddi"]', MigrationConstants::NS).map(&:text)
          work_attributes['series'] = descriptive_mods.xpath('mods:relatedItem[@type="series"]', MigrationConstants::NS).map(&:text)
          work_attributes['subject'] = descriptive_mods.xpath('mods:subject/mods:topic', MigrationConstants::NS).map(&:text)
          work_attributes['geographic_subject'] = descriptive_mods.xpath('mods:subject/mods:geographic/@valueURI', MigrationConstants::NS).map(&:text)
          keyword_string = descriptive_mods.xpath('mods:note[@displayLabel="Keywords"]', MigrationConstants::NS).map(&:text)
          work_attributes['keyword'] = []
          keyword_string.each do |keyword|
            if keyword.match(/\n/)
              work_attributes['keyword'].concat keyword.split(/\n/).collect(&:strip)
            elsif keyword.match(';')
              work_attributes['keyword'].concat keyword.split(';').collect(&:strip)
            elsif keyword.match(',')
              work_attributes['keyword'].concat keyword.split(',').collect(&:strip)
            else
              work_attributes['keyword'].concat keyword.split(' ').collect(&:strip)
            end
          end
          languages = descriptive_mods.xpath('mods:language/mods:languageTerm',MigrationConstants::NS).map(&:text)
          work_attributes['language'] = get_language_uri(languages) if !languages.blank?
          work_attributes['resource_type'] = descriptive_mods.xpath('mods:genre',MigrationConstants::NS).map(&:text)
          work_attributes['dcmi_type'] = descriptive_mods.xpath('mods:typeOfResource/@valueURI',MigrationConstants::NS).map(&:text)
          work_attributes['use'] = descriptive_mods.xpath('mods:accessCondition[@type="use and reproduction" and ((@displayLabel!="License" and @displayLabel!="Rights Statement") or not(@displayLabel))]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
          work_attributes['license'] = descriptive_mods.xpath('mods:accessCondition[@displayLabel="License" and @type="use and reproduction"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
          work_attributes['rights_statement'] = descriptive_mods.xpath('mods:accessCondition[@displayLabel="Rights Statement" and @type="use and reproduction"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
          work_attributes['rights_holder'] = descriptive_mods.xpath('mods:accessCondition/rights:copyright/rights:rights.holder/rights:name',MigrationConstants::NS).map(&:text)
          work_attributes['access'] = descriptive_mods.xpath('mods:accessCondition[@type="restriction on access"]',MigrationConstants::NS).map(&:text)
          work_attributes['doi'] = descriptive_mods.xpath('mods:identifier[@type="doi"]',MigrationConstants::NS).map(&:text)
          work_attributes['identifier'] = descriptive_mods.xpath('mods:identifier[@type="pdf"]/identifier[@type="pmpid"]',MigrationConstants::NS).map(&:text)
          work_attributes['isbn'] = descriptive_mods.xpath('mods:identifier[@type="isbn"]',MigrationConstants::NS).map(&:text)
          work_attributes['issn'] = descriptive_mods.xpath('mods:relatedItem/mods:identifier[@type="issn"]',MigrationConstants::NS).map(&:text)
          work_attributes['publisher'] = descriptive_mods.xpath('mods:originInfo/mods:publisher',MigrationConstants::NS).map(&:text)
          work_attributes['place_of_publication'] = descriptive_mods.xpath('mods:originInfo/mods:place/mods:placeTerm',MigrationConstants::NS).map(&:text)
          work_attributes['journal_title'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:titleInfo/mods:title',MigrationConstants::NS).map(&:text)
          work_attributes['journal_volume'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:detail[@type="volume"]/mods:number',MigrationConstants::NS).map(&:text)
          work_attributes['journal_issue'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:detail[@type="issue"]/mods:number',MigrationConstants::NS).map(&:text)
          work_attributes['page_start'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:extent[@unit="page"]/mods:start',MigrationConstants::NS).map(&:text)
          work_attributes['page_end'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:extent[@unit="page"]/mods:end',MigrationConstants::NS).map(&:text)
          work_attributes['related_url'] = descriptive_mods.xpath('mods:relatedItem/mods:location/mods:url',MigrationConstants::NS).map(&:text)
          work_attributes['url'] = descriptive_mods.xpath('mods:location/mods:url',MigrationConstants::NS).map(&:text)
          work_attributes['publisher_version'] = descriptive_mods.xpath('mods:location/mods:url[@displayLabel="Publisher Version"] | mods:relatedItem[@type="otherVersion"]/mods:location',MigrationConstants::NS).map(&:text)
          work_attributes['digital_collection'] = descriptive_mods.xpath('mods:relatedItem[@displayLabel="Collection" and @type="host"]/mods:titleInfo/mods:title',MigrationConstants::NS).map(&:text)
        end

        # RDF information
        work_attributes['deposit_record'] = ''
        work_attributes['cdr_model_type'] = ''
        rdf_version = metadata.xpath("//rdf:RDF", MigrationConstants::NS).last
        if rdf_version
          # Check for deposit record
          if rdf_version.to_s.match(/originalDeposit/)
            work_attributes['deposit_record'] = rdf_version.xpath('rdf:Description/*[local-name() = "originalDeposit"]/@rdf:resource', MigrationConstants::NS).map(&:text)
          end

          # Check if aggregate work
          if rdf_version.to_s.match(/hasModel/)
            work_attributes['cdr_model_type'] = rdf_version.xpath('rdf:Description/*[local-name() = "hasModel"]/@rdf:resource', MigrationConstants::NS).map(&:text)
          end

          # Create lists of attached files and children
          if rdf_version.to_s.match(/resource/)
            contained_files = rdf_version.xpath("rdf:Description/*[not(local-name()='originalDeposit') and not(local-name() = 'defaultWebObject') and contains(@rdf:resource, 'uuid')]", MigrationConstants::NS)
            contained_files.each do |contained_file|
              tmp_uuid = get_uuid_from_path(contained_file.to_s)
              if work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork'
                if !@binary_hash[tmp_uuid].blank? && !(@collection_uuids.include? tmp_uuid)
                  work_attributes['contained_files'] << tmp_uuid
                elsif !@object_hash[tmp_uuid].blank? && tmp_uuid != uuid
                  child_works << tmp_uuid
                end
              else
                if !@binary_hash[tmp_uuid].blank?
                  work_attributes['contained_files'] << tmp_uuid
                end
              end
            end

            if work_attributes['contained_files'].count > 1
              representative = rdf_version.xpath('rdf:Description/*[local-name() = "defaultWebObject"]/@rdf:resource', MigrationConstants::NS).to_s.split('/')[1]
              if representative
                work_attributes['contained_files'] -= [get_uuid_from_path(representative)]
                work_attributes['contained_files'] = [get_uuid_from_path(representative)] + work_attributes['contained_files']
              end
            end
            work_attributes['contained_files'].uniq!
          end


          # Set access controls for work
          # Set default visibility first
          private_visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
          public_visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
          work_attributes['embargo_release_date'] = ''
          work_attributes['visibility'] = public_visibility

          if rdf_version.to_s.match(/metadata-patron/)
            patron = rdf_version.xpath("rdf:Description/*[local-name() = 'metadata-patron']", MigrationConstants::NS).text
            if patron == 'public'
              if rdf_version.to_s.match(/contains/)
                work_attributes['visibility'] = public_visibility
              else
                work_attributes['visibility'] =private_visibility
              end
            end
          elsif rdf_version.to_s.match(/embargo-until/)
            embargo_release_date = Date.parse rdf_version.xpath("rdf:Description/*[local-name() = 'embargo-until']", MigrationConstants::NS).text
            work_attributes['embargo_release_date'] = (Date.try(:edtf, embargo_release_date) || embargo_release_date).to_s
            work_attributes['visibility'] = private_visibility
            work_attributes['visibility_during_embargo'] = private_visibility
            work_attributes['visibility_after_embargo'] = public_visibility
          elsif rdf_version.to_s.match(/isPublished/)
            published = rdf_version.xpath("rdf:Description/*[local-name() = 'isPublished']", MigrationConstants::NS).text
            if published == 'no'
              work_attributes['visibility'] = private_visibility
            end
          elsif rdf_version.to_s.match(/inheritPermissions/)
            inherit = rdf_version.xpath("rdf:Description/*[local-name() = 'inheritPermissions']", MigrationConstants::NS).text
            if inherit == 'false'
              work_attributes['visibility'] = private_visibility
            end
          elsif rdf_version.to_s.match(/cdr-role:patron>authenticated/)
            authenticated = rdf_version.xpath("rdf:Description/*[local-name() = 'patron']", MigrationConstants::NS).text
            if authenticated == 'authenticated'
              work_attributes['visibility'] = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
            end
          end
        end


        # Add work to specified collection
        work_attributes['member_of_collections'] = Array(Collection.where(title: @collection_name).first)
        # Create collection if it does not yet exist
        if !@collection_name.blank? && work_attributes['member_of_collections'].first.blank?
          user_collection_type = Hyrax::CollectionType.where(title: 'User Collection').first.gid
          work_attributes['member_of_collections'] = Array(Collection.create(title: [@collection_name],
                                         depositor: @depositor.uid,
                                         collection_type_gid: user_collection_type))
        end

        work_attributes['admin_set_id'] = (AdminSet.where(title: @admin_set).first || AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first).id

        { work_attributes: work_attributes.reject!{|k,v| v.blank?}, child_works: child_works }
      end

      private

        def get_uuid_from_path(path)
          path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
        end

        def parse_names_from_mods(mods, name)
          names = mods.xpath('mods:name[mods:role/mods:roleTerm/text()="'+name+'"]', MigrationConstants::NS)
          name_array = []
          names.each do |name|
            if !name.xpath('mods:namePart[@type="family"]', MigrationConstants::NS).text.blank?
              name_array << name.xpath('concat(mods:namePart[@type="family"], ", ", mods:namePart[@type="given"])', MigrationConstants::NS)
            else
              name_array << name.xpath('mods:namePart', MigrationConstants::NS).text
            end
          end

          name_array
        end

        # Use language code to get iso639-2 uri from service
        def get_language_uri(language_codes)
          language_codes.map{|e| LanguagesService.label("http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}") ?
                                "http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}" : e}
        end
    end
  end
end
