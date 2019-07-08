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
                      resourceTypeGeneral: resource_type_parse(record['resource_type_tesim'])
                  },
                  url: "https://cdr.lib.unc.edu/concern/#{record['has_model_ssim'].first.downcase}s/#{record['id']}?locale=en",
                  event: 'draft',
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

    def create_doi(record)
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

    def create_single_doi(record_id)
      record = ActiveFedora::SolrService.get("id:#{record_id}", :rows => 1)["response"]["docs"]

      if record.length > 0
        puts "Attempting to create DOI for record #{record[0]['id']}."
        create_doi(record[0])
      else
        Rails.logger.warn "Record with id #{record_id} not found. DOI not added."
      end
    end

    def create_batch_doi
      records = ActiveFedora::SolrService.get("visibility_ssi:open AND -doi_tesim:* AND (workflow_state_name_ssim:deposited OR (*:* -workflow_state_name_ssim:*))",
                                              :rows => @rows)["response"]["docs"]

      if records.length > 0
        records.each do |record|
          puts "Attempting to create DOI for record #{record['id']}."
          create_doi(record)
        end
      else
        Rails.logger.info 'There are no records that need to have DOIs added.'
      end
    end

    def parse_field(record, field)
      record.has_key?(field) ? record["#{field}"] : []
    end

    # Field uses a controlled vocabulary
    def resource_type_parse(resource)
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

    def parse_funding(record, field)
      formatted_values = ->(work) {
        work.map do |f|
          { funderName: f }
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
              person_affiliation = m[0].split(':').last.strip

              # Some most specific affiliations have one or more commas in them
              if DepartmentsService.label(person_affiliation).nil?
                affiliations = person_affiliation.split(',')
                person_affiliation = affiliations.last.strip

                if DepartmentsService.label(person_affiliation).nil?
                  person_affiliation = affiliations.slice(-2, affiliations.length).join(',').strip

                  if DepartmentsService.label(person_affiliation).nil?
                    person_affiliation = affiliations.slice(-3, affiliations.length).join(',').strip
                  end
                end
              end

              person[:affiliation] = person_affiliation
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
# scl enable rh-ruby24 -- bundle exec rake add_dois[2,true]
# Hyc::DoiCreate.create_single_doi('jw827b648')