# frozen_string_literal: true
module Tasks
  module PubmedIngest
    module Recurring
      module Utilities
        class OaSubsetService
          def initialize(start_date:, end_date:, output_path:)
            @start_date = start_date
            @end_date = end_date
            @output_path = output_path
          end

          # WIP: Can probably remove output_path argument later
          # Retrieve OA subset and write to .jsonl file
          def retrieve_oa_subset(start_date: @start_date, end_date: @end_date, output_path: @output_path)
            Rails.logger.info("[OaSubsetService] Retrieving OA subset between #{start_date} and #{end_date}")
            current_start = start_date
            File.open(output_path, 'a') do |file|
              while current_start < end_date
                current_end = [current_start + 1.month - 1.day, end_date].min
                base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi'
                current_url = "#{base_url}?from=#{current_start.strftime('%Y-%m-%d')}&until=#{current_end.strftime('%Y-%m-%d')}"
                # WIP: For testing purposes, we can limit the number of pages to retrieve
                # Remove the `page` variable and the condition in production
                page = 1
                loop do
                  Rails.logger.info("[OaSubsetService] Fetching OA records from #{current_url}")
                  res = HTTParty.get(current_url)

                  unless res.code == 200
                    Rails.logger.error("[OaSubsetService] Failed to retrieve OA metadata: #{res.code} - #{res.message}")
                    Rails.logger.error("[OaSubsetService] URL: #{current_url}")
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
                  # WIP: Break early for testing purposes
                end
                Rails.logger.info("[OaSubsetService] Retrieved OA records from #{current_start} to #{current_end}")
                current_start = current_end + 1.day
                break if page >= 2 # Remove this line in production
                page += 1
              end
            end

            Rails.logger.info("[OaSubsetService] Completed OA subset retrieval into #{output_path}")
          end

          # WIP: Can probably remove output_path argument later
          # Expand PMC OA subset by a buffer (e.g., 2 years)
          def expand_subset(buffer:, output_path: @output_path)
            new_start = @end_date + 1.day
            new_end = @end_date + buffer

            Rails.logger.info("[OaSubsetService] Expanding OA subset from #{new_start} to #{new_end}")
            retrieve_oa_subset(start_date: new_start, end_date: new_end, output_path: output_path)
          end

          # Extract PMC IDs from OA subset file
          def extract_pmc_ids_from_file
            Rails.logger.info("[OaSubsetService] Extracting PMC IDs from #{@output_path}")

            pmc_ids = []
            File.foreach(@output_path) do |line|
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
  end
end
