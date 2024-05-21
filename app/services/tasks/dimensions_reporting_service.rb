# frozen_string_literal: true
module Tasks
    class DimensionsReportingService
        def initialize(ingested_publications)
            @ingested_publications = ingested_publications
        end

        def report
            Rails.logger.info("Reporting publications from dimensions ingest at #{ingested_publications[:time]} by #{ingested_publications[:depositor]}.")
            Rails.logger.info("Admin Set: #{@ingested_publications[:admin_set_title]}")
            Rails.logger.info("Depositor: #{@ingested_publications[:depositor]}")
            extracted_info = extract_publication_info()
            Rails.logger.info("Successfully Ingested:\n")
            Rails.logger.info("#{extracted_info[:successfully_ingested].join("\n")}")
            Rails.logger.info("Marked for Review:\n")
            Rails.logger.info("#{extracted_info[:marked_for_review].join("\n")}")
            Rails.logger.info("Failed to Ingest:\n")
            Rails.logger.info("#{extracted_info[:failed_to_ingest].join("\n")}")
        end

        def extract_publication_info
            publication_info = {successfully_ingested: [], failed_to_ingest: [], marked_for_review: []}
            @ingested_publications[:ingested].map do |publication|
                if publication['marked_for_review']
                    publication_info[:marked_for_review] << "Title: #{publication['title']}, ID: #{publication['id']}, URL: #{publication['url']}, PDF Attached: #{publication['pdf_attached'] ? 'Yes' : 'No'}"
                else
                    publication_info[:successfully_ingested] << "Title: #{publication['title']}, ID: #{publication['id']}, URL: #{publication['url']}, PDF Attached: #{publication['pdf_attached'] ? 'Yes' : 'No'}"
                end
            end
            @ingested_publications[:failed].map do |publication|
                publication_info[:failed_to_ingest] << "Title: #{publication['title']}, ID: #{publication['id']}, URL: #{publication['url']}, Error: #{publication['error'][0]} - #{publication['error'][1]}"
            end
        end
    end
end