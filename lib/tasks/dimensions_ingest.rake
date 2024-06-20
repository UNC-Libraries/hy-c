# frozen_string_literal: true
namespace :dimensions do
  DIMENSIONS_URL = 'https://app.dimensions.ai/api/'
  EARLIEST_DATE = '1970-01-01'

  desc 'Ingest metadata and publications from Dimensions'
  task :ingest_publications, [:admin_set, :start_date, :end_date] => :environment do |t, args|
    Rails.logger.info "[#{Time.now}] starting dimensions publications ingest"
    is_cron_job = FALSE

    start_date = args[:start_date]
    end_date = args[:end_date]

    # Ensure start_date and end_date are provided, or neither are provided
    if args[:start_date].present? && !args[:end_date].present?
      raise ArgumentError, 'Both start_date and end_date must be provided if specifying a date range. Only start_date provided.'
    elsif !args[:start_date].present? && args[:end_date].present?
      raise ArgumentError, 'Both start_date and end_date must be provided if specifying a date range. Only end_date provided.'
    end

    # Determine the date range to use for the query
    if args[:start_date] && args[:end_date]
      start_date = Date.parse(args[:start_date]).strftime('%Y-%m-%d')
      end_date = Date.parse(args[:end_date]).strftime('%Y-%m-%d')
      Rails.logger.info "Using provided date range: #{start_date} to #{end_date}"
    else
      # Read the last run time from a file
      file_path = File.join(ENV['DATA_STORAGE'], 'last_dimensions_ingest_run.txt')
      last_run_time = File.exist?(file_path) ? Date.parse(File.read(file_path).strip) : nil
      if last_run_time
        Rails.logger.info "Last ingest run was at: #{last_run_time}"
        start_date = last_run_time.strftime('%Y-%m-%d')
      else
        Rails.logger.info "No previous run time found. Starting from default date. (#{EARLIEST_DATE})"
        start_date = EARLIEST_DATE
      end
      is_cron_job = TRUE
      end_date = Date.today.strftime('%Y-%m-%d')
      Rails.logger.info "Using date range: #{start_date} to #{end_date}"
    end

    formatted_last_run_time = last_run_time ? last_run_time.strftime('%Y-%m-%d') : nil

    config = {
      'admin_set' => args[:admin_set],
      'depositor_onyen' => ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'],
    }

    # Query and ingest publications
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    publications = ingest_service.ingest_publications(query_service.query_dimensions(start_date: start_date, end_date: end_date))
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

    # Write the last run time to a file only if this is a cron job
    if is_cron_job
      File.open(Rails.root.join('log', 'last_dimensions_ingest_run.txt'), 'w') do |f|
        f.puts Time.current
      end
    else
      Rails.logger.info 'Not a cron job. Skipping writing last run time to file.'
    end
  end
end
