module Hyc
  class DoiCreate
    def initialize(rows = 1000)
      @rows = rows
      @use_test_api = ENV['DATACITE_USE_TEST_API'].to_s.downcase == "true"
      @doi_prefix = ENV['DATACITE_PREFIX']
      if @use_test_api
        @doi_creation_url = 'https://api.test.datacite.org/dois'
        @doi_url_base = 'https://handle.test.datacite.org'
      else
        @doi_creation_url = 'https://api.datacite.org/dois'
        @doi_url_base = 'https://doi.org'
      end
      @doi_user = ENV['DATACITE_USER']
      @doi_password = ENV['DATACITE_PASSWORD']
    end

    def doi_request(data)
      HTTParty.post(@doi_creation_url,
                    headers: {'Content-Type' => 'application/vnd.api+json'},
                    basic_auth: {
                        username: @doi_user,
                        password: @doi_password
                    },
                    body: data
      )
    end

    def format_data(record, work)
      data = {
          data: {
              type: 'dois',
              attributes: {
                  prefix: @doi_prefix,
                  titles: [{ title: record['title_tesim'].first }],
                  types: {
                      resourceTypeGeneral: resource_type_parse(record['dcmi_type_tesim'], record['resource_type_tesim'])
                  },
                  url: "#{ENV['HYRAX_HOST']}/concern/#{record['has_model_ssim'].first.downcase}s/#{record['id']}?locale=en",
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

      dates = parse_field(record,'date_issued_tesim')
      if dates.blank?
        [{ date: Date.today.to_s, dateType: 'Issued'}]
      else
        [{ date: dates.first, dateType: 'Issued'}]
      end

      publisher = parse_field(record, 'publisher_tesim')
      if publisher.blank?
        data[:data][:attributes][:publisher] = 'The University of North Carolina at Chapel Hill University Libraries'
      else
        data[:data][:attributes][:publisher] = publisher.first
      end

      publication_year = parse_field(record, 'date_issued_tesim')
      if publication_year.blank?
        data[:data][:attributes][:publicationYear] = Date.today.year
      else
        data[:data][:attributes][:publicationYear] = publication_year.first.match(/\d{4}/)[0]
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

      description = parse_description(record, 'abstract_tesim')
      unless description.blank?
        data[:data][:attributes][:descriptions] = description
      end

      funding = parse_funding(record, 'funder_tesim')
      unless funding.blank?
        data[:data][:attributes][:fundingReferences] = funding
      end

      language = parse_field(record, 'language_label_tesim').first
      unless language.blank?
        data[:data][:attributes][:language] = language
      end

      rights = parse_field(record, 'rights_statement_tesim')
      unless rights.blank?
        data[:data][:attributes][:rightsList] = CdrRightsStatementsService.label(rights.first)
      end

      sizes = parse_field(record, 'extent_tesim')
      unless sizes.blank?
        data[:data][:attributes][:sizes] = sizes
      end

      subjects = parse_subjects(record, 'subject_tesim')
      unless subjects.blank?
        data[:data][:attributes][:subjects] = subjects
      end

      data.to_json
    end

    def create_doi(record)
      puts "Creating DOI for #{record['id']}"
      work = ActiveFedora::Base.find(record['id'])
      record_data = format_data(record, work)
      response = doi_request(record_data)

      if response.success?
        doi = JSON.parse(response.body)['data']['id']
        full_doi = "#{@doi_url_base}/#{doi}"
        work.doi = full_doi
        work.save!

        puts "DOI created for record #{record['id']}: #{full_doi}"
      else
        puts "ERROR: Unable to create DOI for record #{record['id']}. Reason: \"#{response}\""
      end

      sleep(2)
    end

    def create_batch_doi
      start_time = Time.now
      records = ActiveFedora::SolrService.get("visibility_ssi:open AND -doi_tesim:* AND workflow_state_name_ssim:deposited AND has_model_ssim:(Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork)",
                                              :rows => @rows,
                                              :sort => "system_create_dtsi ASC")["response"]["docs"]


      if records.length > 0
        puts "Preparing to add DOIs to #{records.length} records"
        records.each do |record|
          create_doi(record)
        end
        puts "Added #{records.length} DOIs in #{Time.now - start_time}s"
      else
        puts 'There are no records that need to have DOIs added.'
      end
    end

    def parse_field(record, field)
      record.has_key?(field) ? record["#{field}"] : []
    end

    # Field uses a controlled vocabulary
    def resource_type_parse(dcmi_type, record_type)
      unless dcmi_type.nil?
        return dcmi_type.first.split('/').last
      end

      resource_type = (record_type.nil?) ? '' : record_type.first
      case resource_type
      when 'Dataset'
        'Dataset'
      when 'Image'
        'Image'
      when 'Audio'
        'Sound'
      when 'Software or Program Code'
        'Software'
      when 'Video'
        'Audiovisual'
      when ''
        'Other'
      else
        'Text'
      end
    end

    def parse_funding(record, field)
      formatted_values = ->(work) {
        work.map do |f|
          { funderName: f }
        end
      }
      get_values(record["#{field}"], formatted_values)
    end

    def parse_subjects(record, field)
      formatted_values = ->(work) {
        work.map do |s|
          { subject: s }
        end
      }
      get_values(record["#{field}"], formatted_values)
    end

    def parse_description(record, field)
      formatted_values = ->(work) { work.map { |d| { description: d, descriptionType: 'Abstract' }}}
      get_values(record["#{field}"], formatted_values)
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

    private
    def get_values(record_field, process_method)
      values = []

      unless record_field.blank?
        values = process_method.call(record_field)
      end

      values
    end
  end
end