# frozen_string_literal: true
desc 'Ingest new PDFs from the NSF backlog and attach them to Hyrax works if matched'
task :nsf_backlog_ingest, [:file_info_csv, :file_retrieval_directory, :output_dir, :admin_set_title, :depositor_onyen] => :environment do |task, args|
  return unless valid_args('nsf_ingest', args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title], args[:depositor_onyen], args[:file_info_csv])
  config = build_config(args)
  coordinator = Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService.new(config)
  res = coordinator.run
end

def build_config(args)
  now = Time.now
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                               args[:file_retrieval_directory] :
                               Rails.root.join(args[:file_retrieval_directory])
  config = {
    'time' => now,
    'start_date' => args[:start_date] ? Date.parse(args[:start_date]) : nil,
    'end_date' => args[:end_date] ? Date.parse(args[:end_date]) : nil,
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => args[:depositor_onyen],
    'output_dir' => args[:output_dir] || Rails.root.join('tmp', "nsf_ingest_#{now.strftime('%Y-%m-%d_%H-%M-%S')}").to_s,
    'file_retrieval_directory' => file_retrieval_directory,
    'file_info_csv' => args[:file_info_csv]
  }
  write_intro_banner(config: config)
  config
rescue ArgumentError => e
  puts "❌ Invalid date format: #{e.message}"
  exit(1)
end

def write_intro_banner(config:)
  banner_lines = [
    '=' * 80,
    '  NSF Ingest',
    '-' * 80,
    "  Start Time: #{config['time'].strftime('%Y-%m-%d %H:%M:%S')}",
    "  Output Dir: #{config['output_dir']}",
    "  File Retrieval Dir: #{config['file_retrieval_directory']}",
    "  Depositor:  #{config['depositor_onyen']}",
    "  Admin Set:  #{config['admin_set_title']}",
    "  Date Range: #{config['start_date']} to #{config['end_date']}",
    '=' * 80
  ]
  banner_lines.each { |line| puts(line); Rails.logger.info(line) }
end
