# frozen_string_literal: true
namespace :dimensions do
  DIMENSIONS_URL = 'https://app.dimensions.ai/api/'

  desc 'Ingest metadata from Dimensions'
  task ingest_metadata: :environment do
    Rake::Task['dimensions:ingest_metadata_task'].invoke
  end

  desc 'Ingest metadata from Dimensions (implementation)'
  task ingest_metadata_task: :environment do
    Rails.logger.info "[#{Time.now}] starting dimensions metadata ingest"

    # Read the last run time from a file
    file_path = Rails.root.join('log', "last_dimensions_ingest_run.txt")
    last_run_time = File.exist?(file_path) ? Date.parse(File.read(file_path).strip) : nil
    formatted_last_run_time = last_run_time ? last_run_time.strftime('%Y-%m-%d') : nil

    if last_run_time
      Rails.logger.info "Last ingest run was at: #{last_run_time}"
      formatted_last_run_time = last_run_time.strftime('%Y-%m-%d')
    else
      Rails.logger.info 'No previous run time found. Starting from default date. (1970-01-01)'
    end
    config = {
      'admin_set' => 'Open_Acess_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin'
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
      Rails.logger.info "[#{Time.now}] completed dimensions metadata ingest"
    rescue StandardError => e
      Rails.logger.error "Failed to send test email: #{e.message}"
    end

    # Write the last run time to a file
    File.open(Rails.root.join('log', "last_dimensions_ingest_run.txt"), 'w') do |f|
       f.puts Time.current
    end
  end
end
