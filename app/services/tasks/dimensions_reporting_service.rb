# frozen_string_literal: true
module Tasks
  class DimensionsReportingService
    def initialize(ingested_publications)
      @ingested_publications = ingested_publications
    end

    def generate_report
      report = { successfully_ingested_rows: [], marked_for_review_rows: [], failed_to_ingest_rows: [], subject: [], headers: { }}
      extracted_info = extract_publication_info
      formatted_time = @ingested_publications[:time].strftime('%B %d, %Y at %I:%M %p %Z')
      report[:subject] = "Dimensions Ingest Report for #{formatted_time}"
      report[:headers][:reporting_message] = "Reporting publications from dimensions ingest at #{formatted_time} by #{@ingested_publications[:depositor]}."
      report[:headers][:admin_set] = "Admin Set: #{@ingested_publications[:admin_set_title]}"
      report[:headers][:total_publications] = "Total Publications: #{extracted_info[:successfully_ingested].length + extracted_info[:failed_to_ingest].length + extracted_info[:marked_for_review].length}"
      report[:headers][:successfully_ingested] = "\nSuccessfully Ingested: (#{extracted_info[:successfully_ingested].length} Publications)"
      report[:headers][:marked_for_review] = "\nMarked for Review: (#{extracted_info[:marked_for_review].length} Publications)"
      report[:headers][:failed_to_ingest] = "\nFailed to Ingest: (#{extracted_info[:failed_to_ingest].length} Publications)"
      report[:successfully_ingested_rows] = extracted_info[:successfully_ingested]
      report[:marked_for_review_rows] = extracted_info[:marked_for_review]
      report[:failed_to_ingest_rows] = extracted_info[:failed_to_ingest]
      report
    end

    def extract_publication_info
      publication_info = {successfully_ingested: [], failed_to_ingest: [], marked_for_review: []}
      @ingested_publications[:ingested].map do |publication|
        if publication['marked_for_review']
          publication_info[:marked_for_review] << { title: publication['title'], id: publication['id'], url: "https://cdr.lib.unc.edu/concern/articles/#{publication['article_id']}?locale=en", pdf_attached: publication['pdf_attached'] ? 'Yes' : 'No' }
        else
          publication_info[:successfully_ingested] << { title: publication['title'], id: publication['id'], url: "https://cdr.lib.unc.edu/concern/articles/#{publication['article_id']}?locale=en", pdf_attached: publication['pdf_attached'] ? 'Yes' : 'No' }
        end
      end
      @ingested_publications[:failed].map do |publication|
        publication_info[:failed_to_ingest] << { title: publication['title'], id: publication['id'], error: "#{publication['error'][0]} - #{publication['error'][1]}" }
      end
      publication_info
    end
  end
end
