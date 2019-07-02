module Hyc
  module DoiCreate
    @is_test = true

    def self.doi_request(data)
      if @is_test
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

    def self.format_data(record)
      doi_prefix = @is_test ? ENV['DOI_TEST_PREFIX'] : ENV['DOI_PREFIX']
      data = {
          data: {
              type: 'dois',
              attributes: {
                  prefix: doi_prefix,
                  titles: [{ title: record['title_tesim'].first }],
                  types: {
                      resourceTypeGeneral: resource_type_parse(record['resource_type_tesim'])
                  },
                  url: "https://cdr.lib.unc.edu/concern/#{record['has_model_ssim'].first.downcase}s/#{record['id']}?locale=en",
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
        data[:data][:attributes][:language] = language.first
      end

      rights = parse_field(record, 'rights_statement_tesim')
      unless rights.blank?
        data[:data][:attributes][:rightsList] = CdrRightsStatementsService.label(rights.first)
      end

      sizes = parse_field(record, 'extent_tesim')
      unless sizes.blank?
        data[:data][:attributes][:sizes] = sizes
      end

      subjects = parse_field(record, 'subject_tesim')
      unless subjects.blank?
        data[:data][:attributes][:sizes] = subjects
      end

      data.to_json
    end

    def self.create_doi(record)
      response = doi_request(format_data(record))

      if response.success?
        doi = JSON.parse(response.body)['data']['id']
        work = ActiveFedora::Base.find(record['id'])
        work.doi = "https://doi.org/#{doi}"
        work.save!
        Rails.logger.info "DOI created for record #{record['id']} via DataCite."
      else
        Rails.logger.warn "Unable to create DOI for record #{record['id']} via DataCite. DOI not added. Reason: \"#{response}\""
      end
    end

    def self.create_single_doi(record_id)
      record = ActiveFedora::SolrService.get("id:#{record_id}", :rows => 1)["response"]["docs"]

      if record.length > 0
        create_doi(record[0])
      else
        Rails.logger.warn "Record with id #{record_id} not found. DOI not added."
      end
    end

    def self.create_batch_doi
      records = ActiveFedora::SolrService.get("visibility_ssi:open AND -doi_tesim:* AND (workflow_state_name_ssim:deposited OR (*:* -workflow_state_name_ssim:*))",
                                              :rows => 1000)["response"]["docs"]

      if records.length > 0
        records.each { |record| create_doi(record) }
      else
        Rails.logger.info 'There are no records that need to have DOIs added.'
      end
    end

    def self.parse_field(record, field)
      record.has_key?(field) ? record["#{field}"] : []
    end

    # Field uses a controlled vocabulary
    def self.resource_type_parse(resource)
      resource_type = (resource.nil?) ? '' : resource.first
      case resource_type
      when 'Dataset'
        'Dataset'
      when 'Image'
        'Image'
      when 'Audio'
        'sound'
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

    def self.parse_funding(record, field)
      formatted_values = ->(work) {
        work.map do |f|
          { funderName: f }
        end
      }
      get_values(record["#{field}"], formatted_values)
    end

    def self.parse_description(record, field)
      formatted_values = ->(work) { work.map { |d| { description: d, descriptionType: 'Abstract' }}}
      get_values(record["#{field}"], formatted_values)
    end

    def self.parse_people(record, field)
      people = ->(work) {
        work.map  do |p|
          person_values = p.split(/\|\|/)
          person = { name: person_values.first, nameType: 'Personal' }

          person_values.each do |p|
            p.match(/Affiliation:.*/) do |m|
              person[:affiliation] = m[0].split(':').last
                                         .split(',').last.strip
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

    private_class_method def self.get_values(record_field, process_method)
                           values = []

                           unless record_field.blank?
                             values = process_method.call(record_field)
                           end

                           values
                         end
  end
end