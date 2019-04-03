module Migrate
  module Services
    class MetadataParser

      def initialize(metadata_file, object_hash, binary_hash, deposit_record_hash, collection_uuids, depositor, collection_name, admin_set)
        @metadata_file = metadata_file
        @object_hash = object_hash
        @binary_hash = binary_hash
        @deposit_record_hash = deposit_record_hash
        @collection_uuids = collection_uuids
        @collection_name = collection_name
        @depositor = depositor
        @admin_set = admin_set
      end

      def parse
        file_open_time = Time.now
        puts "[#{file_open_time.to_s}] opening xml file"
        metadata = Nokogiri::XML(File.open(@metadata_file))
        puts "[#{Time.now.to_s}] finished opening metadata file in #{Time.now-file_open_time} seconds"

        work_attributes = Hash.new

        # get the uuid of the object
        uuid = MigrationHelper.get_uuid_from_path(metadata.at_xpath('foxml:digitalObject/@PID', MigrationConstants::NS).value)
        puts "[#{Time.now.to_s}] getting metadata for: #{uuid}"

        work_attributes['contained_files'] = Array.new(0)

        # get the date_created
        date_created_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'model#createdDate')]/@VALUE", MigrationConstants::NS).to_s
        work_attributes['date_created'] = DateTime.strptime(date_created_string, '%Y-%m-%dT%H:%M:%S.%N%Z') unless date_created_string.nil?
        # get the modifiedDate
        date_modified_string = metadata.xpath("//foxml:objectProperties/foxml:property[contains(@NAME, 'view#lastModifiedDate')]/@VALUE", MigrationConstants::NS).to_s
        work_attributes['date_modified'] = DateTime.strptime(date_modified_string, '%Y-%m-%dT%H:%M:%S.%N%Z') unless date_modified_string.nil?

        descriptive_mods = metadata.xpath("//foxml:datastream[contains(@ID, 'MD_DESCRIPTIVE')]//foxml:xmlContent//mods:mods", MigrationConstants::NS).last
        dc_metadata = metadata.xpath("//foxml:datastream[@ID='DC']//oai_dc:dc", MigrationConstants::NS)
        work_attributes['dc_title'] = dc_metadata.xpath('dc:title', MigrationConstants::NS).map(&:text)

        if !descriptive_mods
          puts "[#{Time.now.to_s}] #{uuid} No MODS datastream available"
          work_attributes['title'] = work_attributes['dc_title']
          work_attributes['label'] = work_attributes['dc_title']
        else
          work_attributes['title'] = descriptive_mods.xpath('mods:titleInfo[not(@*)]/mods:title', MigrationConstants::NS).map(&:text)
          work_attributes['label'] = work_attributes['title']
          work_attributes['alternative_title'] = descriptive_mods.xpath("mods:titleInfo[@type='alternative' or @type='translated']/mods:title", MigrationConstants::NS).map(&:text)
          work_attributes['creators_attributes'] = parse_people_from_mods(descriptive_mods, 'Creator')
          work_attributes['contributors_attributes'] = parse_people_from_mods(descriptive_mods, 'Contributor')
          work_attributes['advisors_attributes'] = parse_people_from_mods(descriptive_mods, 'Thesis advisor')
          work_attributes['arrangers_attributes'] = parse_people_from_mods(descriptive_mods, 'Arranger')
          work_attributes['composers_attributes'] = parse_people_from_mods(descriptive_mods, 'Composer')
          work_attributes['funder'] = parse_names_from_mods(descriptive_mods, 'Funder')
          work_attributes['project_directors_attributes'] = parse_people_from_mods(descriptive_mods, 'Project director')
          work_attributes['researchers_attributes'] = parse_people_from_mods(descriptive_mods, 'Researcher')
          work_attributes['reviewers_attributes'] = parse_people_from_mods(descriptive_mods, 'Reviewer')
          work_attributes['translators_attributes'] = parse_people_from_mods(descriptive_mods, 'Translator')
          work_attributes['sponsor'] = parse_names_from_mods(descriptive_mods, 'Sponsor')
          work_attributes['degree_granting_institution'] = parse_names_from_mods(descriptive_mods, 'Degree granting institution')
          work_attributes['conference_name'] = descriptive_mods.xpath('mods:name[@displayLabel="Conference" and @type="conference"]/mods:namePart', MigrationConstants::NS).map(&:text)
          date_issued = descriptive_mods.xpath('mods:originInfo/mods:dateIssued', MigrationConstants::NS).map(&:text)
          work_attributes['date_issued'] = date_issued.map{|date| date.to_s}
          copyright_date = descriptive_mods.xpath('mods:originInfo/mods:copyrightDate', MigrationConstants::NS).map(&:text)
          work_attributes['copyright_date'] = copyright_date.map{|date| date.to_s}
          work_attributes['last_modified_date'] = descriptive_mods.xpath('mods:originInfo[@displayLabel="Last Date Modified"]/mods:dateModified', MigrationConstants::NS).map(&:text)
          date_other = descriptive_mods.xpath('mods:originInfo/mods:dateOther', MigrationConstants::NS).map(&:text)
          work_attributes['date_other'] = date_other.map{|date| (Date.try(:edtf, date) || date).to_s}
          date_captured = descriptive_mods.xpath('mods:originInfo/mods:dateCaptured', MigrationConstants::NS).map(&:text)
          work_attributes['date_captured'] = date_captured.map{|date| (Date.try(:edtf, date) || date).to_s}
          work_attributes['graduation_year'] = descriptive_mods.xpath('mods:originInfo[@displayLabel="Date Graduated"]/mods:dateOther', MigrationConstants::NS).map(&:text)
          work_attributes['abstract'] = descriptive_mods.xpath('mods:abstract', MigrationConstants::NS).map(&:text)
          work_attributes['note'] = descriptive_mods.xpath('mods:note[not(@displayLabel="Description" or @displayLabel="Methods" or @type="citation/reference" or @displayLabel="Degree" or @displayLabel="Academic concentration" or @displayLabel="Keywords" or @displayLabel="Honors Level")]', MigrationConstants::NS).map(&:text)
          work_attributes['description'] = descriptive_mods.xpath('mods:note[@displayLabel="Description"]', MigrationConstants::NS).map(&:text)
          work_attributes['methodology'] = descriptive_mods.xpath('mods:note[@displayLabel="Methods"]', MigrationConstants::NS).map(&:text)
          work_attributes['extent'] = descriptive_mods.xpath('mods:physicalDescription/mods:extent', MigrationConstants::NS).map(&:text).join(', ')
          work_attributes['table_of_contents'] = descriptive_mods.xpath('mods:tableOfContents', MigrationConstants::NS).map(&:text)
          work_attributes['bibliographic_citation'] = descriptive_mods.xpath('mods:note[@type="citation/reference"]', MigrationConstants::NS).map(&:text)
          work_attributes['edition'] = descriptive_mods.xpath('mods:originInfo/mods:edition', MigrationConstants::NS).map(&:text)
          work_attributes['peer_review_status'] = descriptive_mods.xpath('mods:genre[@displayLabel="Peer Reviewed"] ', MigrationConstants::NS).map(&:text)

          degrees = descriptive_mods.xpath('mods:note[@displayLabel="Degree"]', MigrationConstants::NS).map(&:text)
          degrees = degrees.map{ |degree| DegreesService.label(degree) } unless degrees.blank?
          work_attributes['degree'] = degrees

          work_attributes['academic_concentration'] = descriptive_mods.xpath('mods:note[@displayLabel="Academic concentration"]', MigrationConstants::NS).map(&:text)

          honors_levels = descriptive_mods.xpath('mods:note[@displayLabel="Honors Level"]', MigrationConstants::NS).map(&:text)
          honors_levels = honors_levels.map{ |level| AwardsService.label(level) } unless honors_levels.blank?
          work_attributes['award'] = honors_levels

          work_attributes['medium'] = descriptive_mods.xpath('mods:physicalDescription/mods:form', MigrationConstants::NS).map(&:text)
          work_attributes['kind_of_data'] = descriptive_mods.xpath('mods:genre[@authority="ddi"]', MigrationConstants::NS).map(&:text)
          work_attributes['series'] = descriptive_mods.xpath('mods:relatedItem[@type="series"]', MigrationConstants::NS).map(&:text)
          work_attributes['subject'] = descriptive_mods.xpath('mods:subject/mods:topic', MigrationConstants::NS).map(&:text)
          work_attributes['based_near_attributes'] = parse_locations_from_mods(descriptive_mods)
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
          work_attributes['language_label'] = work_attributes['language'].map{|l| LanguagesService.label(l) } if !languages.blank?
          work_attributes['resource_type'] = descriptive_mods.xpath('mods:genre[not(@*)]',MigrationConstants::NS).map(&:text)
          work_attributes['dcmi_type'] = descriptive_mods.xpath('mods:typeOfResource/@valueURI',MigrationConstants::NS).map(&:text)
          work_attributes['use'] = descriptive_mods.xpath('mods:accessCondition[@type="use and reproduction" and not(@displayLabel)]',MigrationConstants::NS).map(&:text)
          license = descriptive_mods.xpath('mods:accessCondition[@displayLabel="License" and @type="use and reproduction"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
          work_attributes['license'] = license&.map{|uri| uri.sub(/^https/, 'http')}
          work_attributes['license_label'] = work_attributes['license'].map{ |l| CdrLicenseService.label(l) }
          work_attributes['rights_statement'] = descriptive_mods.xpath('mods:accessCondition[@displayLabel="Rights Statement" and @type="use and reproduction"]/@*[name()="xlink:href"]',MigrationConstants::NS).map(&:text)
          work_attributes['rights_statement_label'] = work_attributes['rights_statement'].map{ |r| CdrRightsStatementsService.label(r) }
          work_attributes['rights_holder'] = descriptive_mods.xpath('mods:accessCondition/rights:copyright/rights:rights.holder/rights:name',MigrationConstants::NS).map(&:text)
          work_attributes['access'] = descriptive_mods.xpath('mods:accessCondition[@type="restriction on access"]',MigrationConstants::NS).map(&:text)
          work_attributes['doi'] = descriptive_mods.xpath('mods:identifier[@type="doi" and @displayLabel="CDR DOI"]',MigrationConstants::NS).map(&:text)
          work_attributes['identifier'] = descriptive_mods.xpath('mods:identifier[@type="pdf" or @type="pmpid" or @type="eid" or @displayLabel="DOI"]',MigrationConstants::NS).map(&:text)
          work_attributes['isbn'] = descriptive_mods.xpath('mods:identifier[@type="isbn"]',MigrationConstants::NS).map(&:text)
          work_attributes['issn'] = descriptive_mods.xpath('mods:relatedItem/mods:identifier[@type="issn"]',MigrationConstants::NS).map(&:text)
          work_attributes['publisher'] = descriptive_mods.xpath('mods:originInfo/mods:publisher',MigrationConstants::NS).map(&:text)
          work_attributes['place_of_publication'] = descriptive_mods.xpath('mods:originInfo/mods:place/mods:placeTerm',MigrationConstants::NS).map(&:text)
          work_attributes['journal_title'] = descriptive_mods.xpath('mods:relatedItem[@type="host" and not(@displayLabel="Collection")]/mods:titleInfo/mods:title',MigrationConstants::NS).map(&:text)
          work_attributes['journal_volume'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:detail[@type="volume"]/mods:number',MigrationConstants::NS).map(&:text)
          work_attributes['journal_issue'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:detail[@type="issue"]/mods:number',MigrationConstants::NS).map(&:text)
          work_attributes['page_start'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:extent[@unit="page"]/mods:start',MigrationConstants::NS).map(&:text)
          work_attributes['page_end'] = descriptive_mods.xpath('mods:relatedItem[@type="host"]/mods:part/mods:extent[@unit="page"]/mods:end',MigrationConstants::NS).map(&:text)
          work_attributes['related_url'] = descriptive_mods.xpath('mods:relatedItem/mods:location/mods:url',MigrationConstants::NS).map(&:text)
          work_attributes['url'] = descriptive_mods.xpath('mods:location/mods:url',MigrationConstants::NS).map(&:text)
          work_attributes['digital_collection'] = descriptive_mods.xpath('mods:relatedItem[@displayLabel="Collection" and @type="host"]/mods:titleInfo/mods:title',MigrationConstants::NS).map(&:text)
        end

        # RDF information
        work_attributes['deposit_record'] = ''
        work_attributes['cdr_model_type'] = ''
        rdf_version = metadata.xpath("//rdf:RDF", MigrationConstants::NS).last
        if rdf_version
          # Check for deposit record
          if rdf_version.to_s.match(/originalDeposit/)
            old_deposit_record_ids = rdf_version.xpath('rdf:Description/*[local-name() = "originalDeposit"]/@rdf:resource', MigrationConstants::NS).map(&:text)
            work_attributes['deposit_record'] = old_deposit_record_ids.map{ |id| @deposit_record_hash[MigrationHelper.get_uuid_from_path(id)] || MigrationHelper.get_uuid_from_path(id) }
          end

          # Check if aggregate work
          if rdf_version.to_s.match(/hasModel/)
            work_attributes['cdr_model_type'] = rdf_version.xpath('rdf:Description/*[local-name() = "hasModel"]/@rdf:resource', MigrationConstants::NS).map(&:text)
          end

          # Create lists of attached files
          if rdf_version.to_s.match(/resource/)
            contained_files = rdf_version.xpath("rdf:Description/*[not(local-name()='originalDeposit') and not(local-name() = 'defaultWebObject') and contains(@rdf:resource, 'uuid')]", MigrationConstants::NS)
            contained_files.each do |contained_file|
              tmp_uuid = MigrationHelper.get_uuid_from_path(contained_file.to_s)
              if work_attributes['cdr_model_type'].include? 'info:fedora/cdr-model:AggregateWork'
                if !@binary_hash[tmp_uuid].blank? && !(@collection_uuids.include? tmp_uuid)
                  work_attributes['contained_files'] << tmp_uuid
                end
              else
                if !@binary_hash[tmp_uuid].blank?
                  work_attributes['contained_files'] << tmp_uuid
                end
              end
            end

            representative = rdf_version.xpath('rdf:Description/*[local-name() = "defaultWebObject"]/@rdf:resource', MigrationConstants::NS).to_s.split('/')[1]
            if representative
              work_attributes['contained_files'] -= [MigrationHelper.get_uuid_from_path(representative)]
              work_attributes['contained_files'] = [MigrationHelper.get_uuid_from_path(representative)] + work_attributes['contained_files']
            end
            work_attributes['contained_files'].uniq!
          end

          # Find premis file
          work_attributes['premis_files'] = []
          premis_mods = metadata.xpath("//foxml:datastream[contains(@ID, 'MD_EVENTS')]", MigrationConstants::NS).last
          if !premis_mods.blank?
            premis_reference = premis_mods.xpath("foxml:datastreamVersion/foxml:contentLocation/@REF", MigrationConstants::NS).map(&:text)
            premis_reference.each do |reference|
              work_attributes['premis_files'] << MigrationHelper.get_uuid_from_path(reference)
            end
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
        MigrationHelper.retry_operation('adding collection') do
          work_attributes['member_of_collections'] = Array(Collection.where(title: @collection_name).first)
        end
        # Create collection if it does not yet exist
        if !@collection_name.blank? && work_attributes['member_of_collections'].first.blank?
          user_collection_type = nil
          MigrationHelper.retry_operation('adding collection') do
            user_collection_type = Hyrax::CollectionType.where(title: 'User Collection').first.gid
          end
          
          MigrationHelper.retry_operation('adding collection') do
            work_attributes['member_of_collections'] = Array(Collection.create(
                title: [@collection_name],
                depositor: @depositor.uid,
                collection_type_gid: user_collection_type))
          end
        end

        work_attributes['admin_set_id'] = @admin_set

        work_attributes.reject!{|k,v| v.blank?}
      end

      private

        def parse_names_from_mods(mods, type)
          names = mods.xpath('mods:name[mods:role/mods:roleTerm/text()="'+type+'"]', MigrationConstants::NS)
          name_array = []
          names.each do |name|
            if !name.xpath('mods:namePart[@type="family"]', MigrationConstants::NS).text.blank?
              name_array << build_name(name)
            else
              name_array << name.xpath('mods:namePart', MigrationConstants::NS).text
            end
          end

          name_array
        end

        def parse_people_from_mods(mods, type)
          people = mods.xpath('mods:name[mods:role/mods:roleTerm/text()="'+type+'"]', MigrationConstants::NS)

          person_hash = Hash.new
          people.each_with_index do |person, index|
            name = ''
            if !person.xpath('mods:namePart[@type="family"]', MigrationConstants::NS).text.blank?
              name = build_name(person)
            else
              name = person.xpath('mods:namePart', MigrationConstants::NS).text
            end
            orcid = person.xpath('mods:nameIdentifier[@type="orcid"]', MigrationConstants::NS).text
            affiliation = person.xpath('mods:affiliation', MigrationConstants::NS).map(&:text)
            other_affiliation = person.xpath('mods:description', MigrationConstants::NS).text

            person_hash[index.to_s] = { 'name' => name,
                                        'orcid' => orcid,
                                        'affiliation' => department_lookup(affiliation),
                                        'other_affiliation' => other_affiliation }
          end

          person_hash.blank? ? nil : person_hash
        end

        def parse_locations_from_mods(mods)
          location_hash = Hash.new

          locations = mods.xpath('mods:subject/mods:geographic/@valueURI', MigrationConstants::NS).map(&:text)
          locations.each_with_index do |location, index|
            location_hash[index.to_s] = { id: location }
          end

          location_hash.blank? ? nil : location_hash
        end

        # Use language code to get iso639-2 uri from service
        def get_language_uri(language_codes)
          language_codes.map{|e| LanguagesService.label("http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}") ?
                                "http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}" : e}
        end

        def department_lookup(affiliations)
          affiliations -= ['University of North Carolina at Chapel Hill']
          merged_affiliations = []
          if !affiliations.blank?
            affiliations.each do |affiliation|
              merged_affiliations << (DepartmentsService.label(affiliation) || affiliation).split('; ')
            end
            merged_affiliations.flatten!
            merged_affiliations.compact.uniq
          else
            []
          end
        end

        def build_name(name_mods)
          name_parts = []
          name_parts << name_mods.xpath('mods:namePart[@type="family"]', MigrationConstants::NS)
          name_parts << name_mods.xpath('mods:namePart[@type="given"]', MigrationConstants::NS)
          name_parts << name_mods.xpath('mods:namePart[@type="termsOfAddress"]', MigrationConstants::NS)
          name_parts << name_mods.xpath('mods:namePart[@type="date"]', MigrationConstants::NS)
          name_parts.reject{ |name| name.blank? }.join(', ')
        end
    end
  end
end
