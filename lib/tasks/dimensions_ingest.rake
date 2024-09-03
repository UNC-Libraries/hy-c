# frozen_string_literal: true
namespace :dimensions do
  DIMENSIONS_URL = 'https://app.dimensions.ai/api/'
  EARLIEST_DATE = '1970-01-01'

  desc 'Ingest metadata and publications from Dimensions'
  task :ingest_publications, [:admin_set, :start_date, :end_date, :deduplicate] => :environment do |t, args|
    Rails.logger.info "[#{Time.now}] starting dimensions publications ingest"
    is_cron_job = false

    start_date = args[:start_date]
    end_date = args[:end_date]
    deduplicate = args[:deduplicate].present? ? args[:deduplicate].downcase == 'true' : true

    # Ensure start_date and end_date are provided, or neither are provided
    if args[:start_date].present? && !args[:end_date].present?
      raise ArgumentError, 'Both start_date and end_date must be provided if specifying a date range. Only start_date provided.'
    elsif !args[:start_date].present? && args[:end_date].present?
      raise ArgumentError, 'Both start_date and end_date must be provided if specifying a date range. Only end_date provided.'
    end

    start_date, end_date, is_cron_job = get_date_range(args)

    config = {
      'admin_set' => args[:admin_set],
      'depositor_onyen' => ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'],
      'wiley_tdm_api_token' => ENV['WILEY_TDM_API_TOKEN'],
      'deduplicate' => deduplicate
    }

    # Query and ingest publications
    query_service = Tasks::DimensionsQueryService.new(config)
    ingest_service = Tasks::DimensionsIngestService.new(config)
    publications = ingest_service.ingest_publications(query_service.query_dimensions(start_date: start_date, end_date: end_date))
    report = Tasks::DimensionsReportingService.new(publications, query_service.dimensions_total_count, { start_date: start_date, end_date: end_date }, is_cron_job).generate_report

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
      File.open(dimensions_last_run_path, 'w') do |f|
        f.puts Time.current
      end
    else
      Rails.logger.info 'Not a cron job. Skipping writing last run time to file.'
    end
  end

    # Helper method to compute the last run file path
  def self.dimensions_last_run_path
    File.join(ENV['DATA_STORAGE'], 'hyrax', 'last_dimensions_ingest_run.txt')
  end

  def self.get_date_range(args)
    if args[:start_date] && args[:end_date]
      start_date = Date.parse(args[:start_date]).strftime('%Y-%m-%d')
      end_date = Date.parse(args[:end_date]).strftime('%Y-%m-%d')
      Rails.logger.info "Using provided date range: #{start_date} to #{end_date}"
      is_cron_job = false
    else
      last_run_time = File.exist?(dimensions_last_run_path) ? Date.parse(File.read(dimensions_last_run_path).strip) : nil
      if last_run_time
        Rails.logger.info "Last ingest run was at: #{last_run_time}"
        start_date = last_run_time.strftime('%Y-%m-%d')
      else
        Rails.logger.info "No previous run time found. Starting from default date. (#{EARLIEST_DATE})"
        start_date = EARLIEST_DATE
      end
      is_cron_job = true
      end_date = Date.today.strftime('%Y-%m-%d')
      Rails.logger.info "Using date range: #{start_date} to #{end_date}"
    end
    [start_date, end_date, is_cron_job]
  end
end
