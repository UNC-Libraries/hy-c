# frozen_string_literal: true
module Tasks
  module PubmedIngest
    class OaSubsetService
      def initialize(output_dir:)
        @output_dir = output_dir || Rails.root.join('tmp')
      end

      # Retrieve OA subset and write to .jsonl file
      def retrieve_oa_subset(start_date:, end_date:, output_file: "#{@output_dir}/oa_subset.jsonl")
        Rails.logger.info("[OaSubsetService] Retrieving OA subset between #{start_date} and #{end_date}")

        base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi'
        current_url = "#{base_url}?from=#{start_date.strftime('%Y-%m-%d')}&until=#{end_date.strftime('%Y-%m-%d')}"

        File.open(output_file, 'a') do |file|
          loop do
            res = HTTParty.get(current_url)

            unless res.code == 200
              Rails.logger.error("[OaSubsetService] Failed to retrieve OA metadata: #{res.code} - #{res.message}")
              break
            end

            xml_doc = Nokogiri::XML(res.body)
            records = xml_doc.xpath('//record')

            records.each do |record|
              record_hash = {
                'pmcid' => record['id'],
                'links' => record.xpath('link').map do |link|
                             {
                               'format' => link['format'],
                               'href'   => link['href'],
                               'updated' => link['updated']
                             }
                           end
              }
              file.puts(record_hash.to_json)
            end

            Rails.logger.info("[OaSubsetService] Retrieved #{records.size} records from current page")

            resumption_link = xml_doc.at_xpath('//resumption/link')&.[]('href')
            break unless resumption_link

            current_url = resumption_link
            sleep(0.34) # Respect NCBI rate limits
          end
        end

        Rails.logger.info("[OaSubsetService] Completed OA subset retrieval into #{output_file}")
      end

      # Expand PMC OA subset by a buffer (e.g., 2 years)
      def expand_subset(current_end_date:, buffer:, output_file: "#{@output_dir}/oa_subset_expanded.jsonl")
        new_start = current_end_date + 1.day
        new_end = current_end_date + buffer

        Rails.logger.info("[OaSubsetService] Expanding OA subset from #{new_start} to #{new_end}")
        retrieve_oa_subset(start_date: new_start, end_date: new_end, output_file: output_file)
      end

      # Extract PMC IDs from OA subset file
      def extract_pmc_ids_from_file(input_file: "#{@output_dir}/oa_subset.jsonl")
        Rails.logger.info("[OaSubsetService] Extracting PMC IDs from #{input_file}")

        pmc_ids = []
        File.foreach(input_file) do |line|
          record = JSON.parse(line)
          pmcid = record['pmcid']
          pmc_ids << pmcid if pmcid.present?
        end

        Rails.logger.info("[OaSubsetService] Extracted #{pmc_ids.uniq.size} unique PMC IDs")
        pmc_ids.uniq
      end
    end
  end
end
