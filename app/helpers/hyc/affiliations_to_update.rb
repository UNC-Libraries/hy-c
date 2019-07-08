### Query to find records to add to records_to_check.json ###
# indented records: http://127.0.0.1:8983/solr/blacklight-core/select?fl=id%20*_display_tesim&indent=on&q=affiliation_label_tesim:*&rows=1000000&wt=json
# record indent off: http://127.0.0.1:8983/solr/blacklight-core/select?fl=id%20*_display_tesim&indent=off&q=affiliation_label_tesim:*&rows=1000000&wt=json

module Hyc
  module AffiliationsToUpdate
    def self.generate_records_to_update(file_path)
      file = File.read file_path
      records = JSON.parse(file)
      records_to_update = []
      people = ['advisor_display_tesim', 'arranger_display_tesim', 'composer_display_tesim', 'contributor_display_tesim',
                'creator_display_tesim', 'project_director_display_tesim', 'researcher_display_tesim',
                'reviewer_display_tesim', 'translator_display_tesim']

      records['response']['docs'].each do |record|
        updated = false

        people.each do |aff_type|
          people_by_aff = []

          if record.has_key?(aff_type)
            record[aff_type].each do |data|
              data.split('||').each do |aff|
                aff.match(/^Affiliation.*/) do |m|
                  value = m[0].gsub('Affiliation:', '')

                  if DepartmentsService.label(value.strip).nil?
                    values = value.split(',')

                    # Some most specific affiliations have commas in them
                    if DepartmentsService.label(values.last.strip).nil?
                      value = values.slice(-2, values.length).join(',')

                      if DepartmentsService.label(value.strip).nil?
                        value = values.slice(-3, values.length).join(',')
                      end
                    else
                      value = values.last.strip
                    end
                  else
                    next
                  end

                  data = data.gsub(/Affiliation.*/, "Affiliation: #{value}")
                  people_by_aff.push(data)
                end
              end
            end
          end

          if people_by_aff.length > 0
            record[aff_type] = people_by_aff
            updated = true
          end
        end

        if updated
          records_to_update.push(record)
        end
      end

      records_to_update.to_json
    end
  end
end