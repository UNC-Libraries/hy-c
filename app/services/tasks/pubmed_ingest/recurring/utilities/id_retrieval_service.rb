# frozen_string_literal: true
module Tasks
    module PubmedIngest
        module Recurring
            module Utilities
                class IdRetrievalService
                    def initialize(start_date:, end_date:)
                        @start_date = start_date
                        @end_date = end_date
                    end

                    def retrieve_ids_within_date_range(path:, db:, retmax: 1000)
                        Rails.logger.info("[PubmedIngestService - retrieve_ids_within_date_range] Fetching IDs within date range: #{@start_date.strftime('%Y-%m-%d')} - #{@end_date.strftime('%Y-%m-%d')} for #{db} database")
                        base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi'
                        count = 0
                        cursor = 0
                        params = {
                            retmax: retmax,
                            db: db,
                            term: "#{@start_date.strftime('%Y/%m/%d')}:#{@end_date.strftime('%Y/%m/%d')}[PDAT]"
                        }
                        File.open(path, 'a') do |file|
                            loop do
                                # WIP: For testing purposes, we can limit the number of pages to retrieve
                                break if cursor > 2000 # Remove this line in production
                                res = HTTParty.get(base_url, query: params.merge({ retstart: cursor}))
                                if res.code != 200
                                    Rails.logger.error("[PubmedIngestService - retrieve_ids_within_date_range] Failed to retrieve IDs: #{res.code} - #{res.message}")
                                    break
                                end
                                parsed_response = Nokogiri::XML(res.body)
                                # add_to_pubmed_id_list(parsed_response)
                                ids = parsed_response.xpath('//IdList/Id').map(&:text).compact
                                file.puts(ids.join("\n"))
                                count += ids.size
                                cursor += retmax
                                break if cursor > parsed_response.xpath('//Count').text.to_i
                            end
                        end
                        Rails.logger.info("[PubmedIngestService - retrieve_ids_within_date_range] Retrieved #{count} IDs from #{db} database")
                    end
                end
            end
        end
    end
end