module Hyc
  class DoiCreate
    def initialize(rows = 1000, use_test_api = true)
      @rows = rows
      @use_test_api = use_test_api
    end

    def doi_request(data)
      if @use_test_api
        url = 'https://api.test.datacite.org/dois'
        user = ENV['DATACITE_TEST_USER']
        password = ENV['DATACITE_TEST_PASSWORD']
      else
        url = 'https://api.datacite.org/dois'
        user = ENV['DATACITE_USER']
        password = ENV['DATACITE_PASSWORD']
      end

      HTTParty.post(url,
                    headers: {'Content-Type' => 'application/vnd.api+json'},
                    basic_auth: {
                        username: user,
                        password: password
                    },
                    body: data
      )
    end

    def format_data(record)
      doi_prefix = @use_test_api ? ENV['DOI_TEST_PREFIX'] : ENV['DOI_PREFIX']
      data = {
          data: {
              type: 'dois',
              attributes: {
                  prefix: doi_prefix,
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
      creators = parse_people(record, 'creator_display_tesim')
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
      contributors = parse_people(record, 'contributor_display_tesim')
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
      Rails.logger.info "Creating DOI for #{record['id']}"
      response = doi_request(format_data(record))

      if response.success?
        doi_url_base = @use_test_api ? 'https://handle.test.datacite.org' : 'https://doi.org'
        doi = JSON.parse(response.body)['data']['id']
        full_doi = "#{doi_url_base}/#{doi}"
        work = ActiveFedora::Base.find(record['id'])
        work.doi = full_doi
        work.save!

        Rails.logger.info "DOI created for record #{record['id']} via DataCite: #{full_doi}"
      else
        Rails.logger.warn "Unable to create DOI for record #{record['id']} via DataCite. DOI not added. Reason: \"#{response}\""
      end

      sleep(2)
    end

    def create_batch_doi
      start_time = Time.now
      records = ActiveFedora::SolrService.get("visibility_ssi:open AND -doi_tesim:* AND workflow_state_name_ssim:deposited AND has_model_ssim:(Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork)",
                                              :rows => @rows)["response"]["docs"]


      if records.length > 0
        Rails.logger.info "Preparing to add DOIs to #{records.length} records"
        records.each do |record|
          create_doi(record)
        end
        Rails.logger.info "Added #{records.length} DOIs in #{Time.now - start_time}s"
      else
        Rails.logger.info 'There are no records that need to have DOIs added.'
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

    def parse_people(record, field)
      people = ->(work) {
        work.map  do |p|
          person_values = p.split(/\|\|/)
          person = { name: person_values.first, nameType: 'Personal' }

          person_values.each do |p|
            p.match(/Affiliation:.*/) do |m|
              affiliation = m[0].gsub('Affiliation:', '')
              person[:affiliation] = affiliation.strip
            end

            p.match(/ORCID.*/) do |m|
              orcid_value = m[0].split('ORCID:')
              person[:nameIdentifiers] = [ nameIdentifier: orcid_value.last.strip, nameIdentifierScheme: 'ORCID']
            end
          end

          person
        end
      }

      get_values(record["#{field}"], people)
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