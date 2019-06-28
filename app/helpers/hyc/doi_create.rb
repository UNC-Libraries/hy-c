module Hyc
  module DoiCreate
    def self.doi_request(data)
      HTTParty.post("https://api.test.datacite.org/dois",
          headers: {'Content-Type' => 'application/vnd.api+json'},
          basic_auth: {
              username: "#{ENV['DATACITE_USER']}",
              password: "#{ENV['DATACITE_PASSWORD']}"
          },
          body: data
      )
    end

    def self.format_data(record)
      data = {
          data: {
            type: 'dois',
            attributes: {
                doi: "#{ENV['DOI_PREFIX']}/4x327-42",
                contributors: parse_people(record, 'contributor_display_tesim'),
                creators: parse_people(record, 'creator_display_tesim'),
                dates:[{ date: parse_field(record,'date_issued_tesim').first, dateType: 'Issued'}],
                descriptions: parse_description(record, 'abstract_tesim'),
                fundingReferences: parse_funding(record, 'funder_tesim'),
                language: parse_field(record, 'language_label_tesim').first,
                publisher: parse_field(record, 'publisher_tesim').first,
                publicationYear: parse_field(record, 'date_issued_tesim').first.match(/\d{4}/)[0],
                rightsList: CdrRightsStatementsService.label(parse_field(record, 'rights_statement_tesim').first),
                sizes: parse_field(record, 'extent_tesim'),
                subjects: parse_field(record, 'subject_tesim'),
                titles: [{ title: record['title_tesim'].first }],
                types: {
                    resourceTypeGeneral: parse_field(record, 'resource_type_tesim').first
                },
                url: "https://cdr.lib.unc.edu/concern/#{record['has_model_ssim'].first.downcase}s/#{record['id']}?locale=en",
                event: 'publish',
                schemaVersion: 'http://datacite.org/schema/kernel-4'
            }
          }
      }

      data.to_json
    end

    def self.create_doi(record)
      data = format_data(record)
      response = doi_request(data)

      if response.success?
        work = ActiveFedora::Base.find(record.id)
        work.doi = response.body.data.attributes.doi
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
      record["#{field}"] ? record["#{field}"] : ['']
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
              person[:affiliation] = m[0].split(':').last.strip
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
      values = ['']

      unless record_field.blank?
        values = process_method.call(record_field)
      end

      values
    end
  end
end
