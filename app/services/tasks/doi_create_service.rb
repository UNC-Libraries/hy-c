module Tasks
  class DoiCreateService
    # From page 38 https://schema.datacite.org/meta/kernel-4.2/doc/DataCite-MetadataKernel_v4.2.pdf
    DCMI_TO_DATACITE_TYPE = {
      'MovingImage' => 'Audiovisual',
      'Collection' => 'Collection',
      'Dataset' => 'Dataset',
      'Event' => 'Event',
      'StillImage' => 'Image',
      'Image' => 'Image',
      'InteractiveResource' => 'InteractiveResource',
      'PhysicalObject' => 'PhysicalObject',
      'Service' => 'Service',
      'Software' => 'Software',
      'Sound' => 'Sound',
      'Text' => 'Text'
    }
    
    RESOURCE_TYPE_TO_DATACITE = {
      '3D Object' => 'InteractiveResource',
      'Art' => 'Other',
      'Article' => 'Text',
      'Audio' => 'Sound',
      'Book' => 'Text',
      'Capstone Project' => 'Other',
      'Conference Proceeding' => 'Text',
      'Dataset' => 'Dataset',
      'Dissertation' => 'Text',
      'Educational Resource' => 'Other',
      'Honors Thesis' => 'Text',
      'Image' => 'Image',
      'Journal' => 'Text',
      'Journal Item' => 'Text',
      'Map or Cartographic Material' => 'Image',
      'Masters Paper' => 'Text',
      'Masters Thesis' => 'Text',
      'Newsletter' => 'Text',
      'Other' => 'Other',
      'Part of Book' => 'Text',
      'Poster' => 'Text',
      'Presentation' => 'Text',
      'Project' => 'Other',
      'Report' => 'Text',
      'Research Paper' => 'Text',
      'Software or Program Code' => 'Software',
      'Undergraduate Thesis' => 'Text',
      'Video' => 'Audiovisual',
      'Working Paper' => 'Text'
    }
    
    def initialize(rows = 1000)
      @rows = rows
      use_test_api = ENV['DATACITE_USE_TEST_API'].to_s.downcase == "true"
      @doi_prefix = ENV['DATACITE_PREFIX']
      if use_test_api
        @doi_creation_url = 'https://api.test.datacite.org/dois'
        @doi_url_base = 'https://handle.test.datacite.org'
      else
        @doi_creation_url = 'https://api.datacite.org/dois'
        @doi_url_base = 'https://doi.org'
      end
      @doi_user = ENV['DATACITE_USER']
      @doi_password = ENV['DATACITE_PASSWORD']
    end

    def doi_request(data, retries = 2)
      begin
        return HTTParty.post(@doi_creation_url,
                      headers: {'Content-Type' => 'application/vnd.api+json'},
                      basic_auth: {
                          username: @doi_user,
                          password: @doi_password
                      },
                      body: data
        )
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        if retries > 0
          retries -= 1
          puts "Timed out while attempting to create DOI using #{@doi_creation_url}, retrying with #{retries} retries remaining."
          sleep(30)
          return doi_request(data, retries)
        else
          raise e
        end
      end
    end

    def format_data(work)
      data = {
          data: {
              type: 'dois',
              attributes: {
                  prefix: @doi_prefix,
                  titles: [{ title: work[:title].first }],
                  types: parse_resource_type(work[:dcmi_type], work[:resource_type]),
                  url: get_work_url(work.class, work.id),
                  event: 'publish',
                  schemaVersion: 'http://datacite.org/schema/kernel-4'
              }
          }
      }

      #########################
      #
      # Required fields
      #
      #########################
      creators = parse_people(work, 'creators')
      if creators.blank?
        data[:data][:attributes][:creators] = {
            name: 'The University of North Carolina at Chapel Hill University Libraries',
            nameType: 'Organizational'
        }
      else
        data[:data][:attributes][:creators] = creators
      end

      publisher = parse_field(work, 'publisher')
      if publisher.blank?
        data[:data][:attributes][:publisher] = 'The University of North Carolina at Chapel Hill University Libraries'
      else
        data[:data][:attributes][:publisher] = publisher.first
      end

      publication_year = parse_field(work, 'date_issued')
      if publication_year.blank?
        data[:data][:attributes][:publicationYear] = Date.today.year
      else
        data[:data][:attributes][:publicationYear] = Array.wrap(publication_year).first.to_s.match(/\d{4}/)[0]
      end

      ############################
      #
      # Optional fields
      #
      ############################
      contributors = parse_people(work, 'contributors')
      unless contributors.blank?
        data[:data][:attributes][:contributors] = contributors
      end

      description = parse_description(work, 'abstract')
      unless description.blank?
        data[:data][:attributes][:descriptions] = description
      end

      funding = parse_funding(work, 'funder')
      unless funding.blank?
        data[:data][:attributes][:fundingReferences] = funding
      end

      language = parse_field(work, 'language_label').first
      unless language.blank?
        data[:data][:attributes][:language] = language
      end

      rights = parse_field(work, 'rights_statement')
      unless rights.blank?
        rights_uri = Array.wrap(rights).first
        rights_label = CdrRightsStatementsService.label(rights_uri)
        data[:data][:attributes][:rightsList] = { rights: rights_label, rightsUri: rights_uri }
      end

      sizes = parse_field(work, 'extent')
      unless sizes.blank?
        data[:data][:attributes][:sizes] = sizes
      end

      subjects = parse_subjects(work, 'subject')
      unless subjects.blank?
        data[:data][:attributes][:subjects] = subjects
      end

      data.to_json
    end

    def create_doi(record)
      puts "Creating DOI for #{record['id']}"
      work = ActiveFedora::Base.find(record['id'])
      record_data = format_data(work)
      response = doi_request(record_data)

      if response.success?
        doi = JSON.parse(response.body)['data']['id']
        full_doi = "#{@doi_url_base}/#{doi}"
        work.update!(doi: full_doi)

        puts "DOI created for record #{record['id']}: #{full_doi}"
      else
        puts "ERROR: Unable to create DOI for record #{record['id']}. Reason: \"#{response}\""
      end

      sleep(2)
    end

    def create_batch_doi
      begin
        start_time = Time.now
        records = ActiveFedora::SolrService.get("visibility_ssi:open AND -doi_tesim:* AND workflow_state_name_ssim:deposited AND has_model_ssim:(Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork)",
                                                :rows => @rows,
                                                :sort => "system_create_dtsi ASC",
                                                :fl => "id")["response"]["docs"]

        if records.length > 0
          puts "Preparing to add DOIs to #{records.length} records"
          records.each do |record|
            create_doi(record)
          end
          puts "Added #{records.length} DOIs in #{Time.now - start_time}s"
          return records.length
        else
          puts 'There are no records that need to have DOIs added.'
          return 0
        end
      rescue => e
        puts "There was an error creating dois: #{e.message}"
        return -1
      end
    end


    private

      def get_values(record_field, process_method)
        values = []

        unless record_field.blank?
          values = process_method.call(record_field)
        end

        values
      end

      def get_work_url(model, id)
        Rails.application.routes.url_helpers.send(Hyrax::Name.new(model).singular_route_key + "_url", id)
      end

      def parse_field(record, field)
        record.attributes.keys.member?(field) ? record[field.to_sym] : []
      end

      # Field uses a controlled vocabulary
      def parse_resource_type(dcmi_type, record_type)
        result = {}

        datacite_type = nil
        if !dcmi_type.blank?
          # Prioritize the "text" type when multiple are present
          if dcmi_type.include?('http://purl.org/dc/dcmitype/Text')
            dcmi_val = 'http://purl.org/dc/dcmitype/Text'
          else
            dcmi_val = dcmi_type.first
          end
          dcmi_type_term = dcmi_val.split('/').last
          datacite_type = DCMI_TO_DATACITE_TYPE[dcmi_type_term]
        else
          # Fall back to resource type mapping
          resource_type = record_type&.first
          datacite_type = RESOURCE_TYPE_TO_DATACITE[resource_type]
        end
        if datacite_type.nil?
          puts "WARNING: Unable to determine resourceTypeGeneral for record"
        end
        # Storing the datacite type. If it is nil or invalid, datacite will reject the creation
        result[:resourceTypeGeneral] = datacite_type

        unless record_type.blank?
          result[:resourceType] = record_type.first
        end

        result
      end

      def parse_funding(record, field)
        if record.attributes.keys.member?(field)
          formatted_values = ->(work) {
            work.map do |f|
              { funderName: f }
            end
          }
          get_values(record["#{field}"], formatted_values)
        end
      end

      def parse_subjects(record, field)
        if record.attributes.keys.member?(field)
          formatted_values = ->(work) {
            work.map do |s|
              { subject: s }
            end
          }
          get_values(record["#{field}"], formatted_values)
        end
      end

      def parse_description(record, field)
        if record.attributes.keys.member?(field)
          formatted_values = ->(work) { work.map { |d| { description: d, descriptionType: 'Abstract' }}}
          get_values(record["#{field}"], formatted_values)
        end
      end

      def parse_people(work, person_field)
        if !work.attributes.keys.member?(person_field)
          return []
        end

        people = []

        work[person_field].each do |p|
          p_json = JSON.parse(p.to_json)
          person = { name: p_json['name'].first, nameType: 'Personal' }

          affil = p_json['affiliation']&.first
          other_affil = p_json['other_affiliation']&.first

          if !affil.blank?
            expanded_affils = DepartmentsService.label(affil)
            person[:affiliation] = expanded_affils.split('; ') unless expanded_affils.nil?
          elsif !other_affil.blank?
            person[:affiliation] = [other_affil]
          end

          orcid = p_json['orcid']&.first
          if !orcid.blank?
            person[:nameIdentifiers] = [ nameIdentifier: orcid, nameIdentifierScheme: 'ORCID']
          end

          people << person
        end

        people
      end
  end
end