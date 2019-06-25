module Hyc
  module DoiCreate
    def self.doi_request(data)
      HTTParty.post(
          'https://api.datacite.org/dois',
          headers: {'Content-Type' => 'application/vnd.api+json'},
          username: ENV.DATACITE_USER,
          password: ENV.DATACITE_PASSWORD,
          body: data
      )
    end

    def self.format_data(record)
      data = {
          data: {
            id: ENV.DOI_PREFIX,
            type: 'dois',
            attributes: {
                contributors: parse_people('contributor_display'),
                creators: parse_people('creator_display'),
                dates:[{ date: record.date_issued, dateType: 'Issued'}],
                descriptions: record&.abstract.map { |a| { description: a.abstract }} ||= [],
                fundingReferences: record&.funder.map { |f| { fundingReference: { name: f }}} ||= [],
                language: record&.language_label.first ||= '',
                publisher: record&.publisher ||= '',
                publicationYear: record.date_issued.match(/\d{4}/)[0],
                rightsList: record&.rights_statement_label || [],
                sizes: record&.extent |= [],
                subjects: record&.subjects ||= [],
                titles: [{ title: record.title }],
                types: {
                    resourceTypeGeneral: record&.resource_type ||= ''
                },
                doi: ENV.DOI_PREFIX,
                event: 'publish',
                schemaVersion: 'http://datacite.org/schema/kernel-4',
                url: 'https://schema.datacite.org/meta/kernel-4.0/index.html'
            }
          }
      }

      data.to_json
    end

    def self.create_doi(record)
      data = format_data(record)
      response = doi_request(data)

      if response.body
        work = ActiveFedora::Base.find(record.id)
        work.doi = response.body.data.attributes.doi
        work.save!
      else
        Rails.logger.warn "Unable to create DOI for record #{record.id} with DataCite. DOI not added."
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

    private_class_method def self.parse_people(field)
      if !record["#{field}"].nil?
        persons = record["#{field}"].map do |p|
          { name: p.gsub(/\|\|.*/, '') }
        end
      else
        persons = []
      end

      persons
    end
  end
end