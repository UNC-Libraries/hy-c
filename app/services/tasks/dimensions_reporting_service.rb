# frozen_string_literal: true
module Tasks
  class DimensionsReportingService
    def initialize(ingested_publications, start_date, end_date, is_cron_job)
      @ingested_publications = ingested_publications
      @start_date = start_date
      @end_date = end_date
      @is_cron_job = is_cron_job
    end

    def generate_report
      report = { successfully_ingested_rows: [], failed_to_ingest_rows: [], subject: [], headers: { }}
      extracted_info = extract_publication_info
      formatted_time = @ingested_publications[:time].strftime('%B %d, %Y at %I:%M %p %Z')
      report[:subject] = "Dimensions Ingest Report for #{formatted_time}"
      report[:headers][:reporting_message] = "Reporting publications from #{@is_cron_job ? 'automated' : 'manually executed'} dimensions ingest on #{formatted_time} by #{@ingested_publications[:depositor]}."
      report[:headers][:date_range] = "Publication Date Range: #{@start_date} to #{@end_date}"
      report[:headers][:admin_set] = "Admin Set: #{@ingested_publications[:admin_set_title]}"
      report[:headers][:total_publications] = "Total Publications: #{extracted_info[:successfully_ingested].length + extracted_info[:failed_to_ingest].length}"
      report[:headers][:successfully_ingested] = "\nSuccessfully Ingested: (#{extracted_info[:successfully_ingested].length} Publications)"
      report[:headers][:failed_to_ingest] = "\nFailed to Ingest: (#{extracted_info[:failed_to_ingest].length} Publications)"
      report[:successfully_ingested_rows] = extracted_info[:successfully_ingested]
      report[:failed_to_ingest_rows] = extracted_info[:failed_to_ingest]
      report
    end

    def extract_publication_info
      publication_info = {successfully_ingested: [], failed_to_ingest: []}
      @ingested_publications[:ingested].map do |publication|
        publication_item = { title: publication['title'], id: publication['id'], url: "#{ENV['HYRAX_HOST']}/concern/articles/#{publication['article_id']}?locale=en", pdf_attached: publication['pdf_attached'] ? 'Yes' : 'No' }
        publication_info[:successfully_ingested] << publication_item
      end
      @ingested_publications[:failed].map do |publication|
        publication_info[:failed_to_ingest] << { title: publication['title'], id: publication['id'], error: "#{publication['error'][0]} - #{publication['error'][1]}" }
      end
      publication_info
    end
  end
end
