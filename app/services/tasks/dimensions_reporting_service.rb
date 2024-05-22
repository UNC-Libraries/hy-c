# frozen_string_literal: true
module Tasks
    class DimensionsReportingService
        def initialize(ingested_publications)
            @ingested_publications = ingested_publications
        end

        def generate_report
            res = []
            extracted_info = extract_publication_info()
            formatted_time = @ingested_publications[:time].strftime("%B %d, %Y at %I:%M %p %Z")
            res << "Reporting publications from dimensions ingest at #{formatted_time} by #{@ingested_publications[:depositor]}."
            res << "Admin Set: #{@ingested_publications[:admin_set_title]}"
            res << "Total Publications: #{extracted_info[:successfully_ingested].length + extracted_info[:failed_to_ingest].length + extracted_info[:marked_for_review].length}"
            res << "\nSuccessfully Ingested: (#{extracted_info[:successfully_ingested].length} Publications)"
            res << extracted_info[:successfully_ingested].join("\n")
            res << "\nMarked for Review: (#{extracted_info[:marked_for_review].length} Publications)"
            res << extracted_info[:marked_for_review].join("\n")
            res << "\nFailed to Ingest: (#{extracted_info[:failed_to_ingest].length} Publications)"
            res << extracted_info[:failed_to_ingest].join("\n")
            res.join("\n")
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
            publication_info
        end
    end
end