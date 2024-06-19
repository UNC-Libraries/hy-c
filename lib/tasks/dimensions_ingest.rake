# frozen_string_literal: true
namespace :dimensions do
  DIMENSIONS_URL = 'https://app.dimensions.ai/api/'

  desc 'Ingest metadata and publications from Dimensions'
  task ingest_publications: :environment do
    Rails.logger.info "[#{Time.now}] starting dimensions publications ingest"

    # Read the last run time from a file
    file_path = File.join(ENV['DATA_STORAGE'], 'last_dimensions_ingest_run.txt')
    last_run_time = File.exist?(file_path) ? Date.parse(File.read(file_path).strip) : nil
    formatted_last_run_time = last_run_time ? last_run_time.strftime('%Y-%m-%d') : nil

    if last_run_time
      Rails.logger.info "Last ingest run was at: #{last_run_time}"
    else
      Rails.logger.info 'No previous run time found. Starting from default date. (1970-01-01)'
    end

    config = {
      'admin_set' => 'Open_Acess_Articles_and_Book_Chapters',
      'depositor_onyen' => ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'],
    }

    # Query and ingest publications
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    publications = ingest_service.ingest_publications(query_service.query_dimensions(date_inserted: formatted_last_run_time))
    report = Tasks::DimensionsReportingService.new(publications).generate_report

    begin
      DimensionsReportMailer.dimensions_report_email(report).deliver_now
      Rails.logger.info 'Dimensions ingest report email sent successfully.'
      Rails.logger.info "Ingested Publications (Total #{publications[:ingested].count}): #{publications[:ingested].map { |pub| pub['id'] }}"
      Rails.logger.info "Failed Publication Ingest (Total #{publications[:failed].count}): #{publications[:failed].map { |pub| pub['id'] }}"
      Rails.logger.info "[#{Time.now}] completed dimensions publications ingest"
    rescue StandardError => e
      Rails.logger.error "Failed to send email: #{e.message}"
    end

    # Write the last run time to a file
    File.open(Rails.root.join('log', 'last_dimensions_ingest_run.txt'), 'w') do |f|
      f.puts Time.current
    end
  end
end
