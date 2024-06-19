# frozen_string_literal: true
namespace :dimensions do
  DIMENSIONS_URL = 'https://app.dimensions.ai/api/'

  desc 'Ingest metadata and publications from Dimensions'
  task :ingest_publications, [:data_storage, :depositor_onyen] => :environment do |t, args|
    data_storage = args[:data_storage]
    depositor_onyen = args[:depositor_onyen]
    puts "[#{Time.now}] starting dimensions publications ingest"

    # Read the last run time from a file
    file_path = File.join(data_storage, 'last_dimensions_ingest_run.txt')
    last_run_time = File.exist?(file_path) ? Date.parse(File.read(file_path).strip) : nil
    formatted_last_run_time = last_run_time ? last_run_time.strftime('%Y-%m-%d') : nil

    if last_run_time
      puts "Last ingest run was at: #{last_run_time}"
    else
      puts 'No previous run time found. Starting from default date. (1970-01-01)'
    end

    config = {
      'admin_set' => 'Open_Acess_Articles_and_Book_Chapters',
      'depositor_onyen' => depositor_onyen,
    }

    # Query and ingest publications
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    publications = ingest_service.ingest_publications(query_service.query_dimensions(date_inserted: formatted_last_run_time))
    report = Tasks::DimensionsReportingService.new(publications).generate_report

    begin
      DimensionsReportMailer.dimensions_report_email(report).deliver_now
      puts 'Dimensions ingest report email sent successfully.'
      puts "Ingested Publications (Total #{publications[:ingested].count}): #{publications[:ingested].map { |pub| pub['id'] }}"
      puts "Failed Publication Ingest (Total #{publications[:failed].count}): #{publications[:failed].map { |pub| pub['id'] }}"
      puts "[#{Time.now}] completed dimensions publications ingest"
    rescue StandardError => e
      puts "Failed to send email: #{e.message}"
    end

    # Write the last run time to a file
    File.open(Rails.root.join('log', 'last_dimensions_ingest_run.txt'), 'w') do |f|
      f.puts Time.current
    end
  end
end
