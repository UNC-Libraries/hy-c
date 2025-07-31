# frozen_string_literal: true
# Notes:
# 1. Script uses PMC-OAI API to retrieve metadata and make comparisons of alternate IDs. (PMCID, PMID)
# 2. PMC requests scripts making >100 requests be ran outside of peak hours. (5 AM - 9 PM)
DEPOSITOR = ENV['PUBMED_INGEST_DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
desc 'Display help for PubMed ingest tasks'
task :pubmed_ingest_help do
  puts <<~HELP
    📘 PubMed Ingest Task Usage

    Usage with positional arguments (less readable):
      bundle exec rake pubmed_ingest[start_date,end_date,admin_set_title,resume,force_overwrite,output_dir]

    Example:
      bundle exec rake pubmed_ingest['2024-01-01','2024-01-15','My Admin Set',true,false,'tmp/ingest_out']

    Recommended: Use ENV-based flags for better readability:

      START_DATE=2024-01-01 \\
      END_DATE=2024-01-15 \\
      ADMIN_SET_TITLE="My Admin Set" \\
      RESUME=true \\
      FORCE_OVERWRITE=false \\
      OUTPUT_DIR=tmp/ingest_out \\
      bundle exec rake pubmed_ingest:with_flags

    Flags:
      START_DATE         (required)  - Start date for ingest range
      END_DATE           (optional)  - End date (defaults to today)
      ADMIN_SET_TITLE    (required)  - Admin set to ingest into
      RESUME             (optional)  - Resume from tracker (true/false)
      FORCE_OVERWRITE    (optional)  - Force overwrite tracker file
      OUTPUT_DIR         (optional)  - Output directory (defaults to tmp/)

    ➕ See also: pubmed_backlog_ingest, pubmed_ingest_help
  HELP
end

task 'pubmed_ingest:with_env_args' => :environment do
  config, ingest_tracker = build_pubmed_ingest_config_and_tracker(env: ENV)
  # coordinator = PubmedIngestCoordinatorService.new(config, ingest_tracker)
  # coordinator.run
end


task :pubmed_ingest, [:start_date, :end_date, :admin_set_title, :resume, :force_overwrite, :output_dir] => :environment do |_, args|
  config, ingest_tracker = build_pubmed_ingest_config_and_tracker(args: args)
  # coordinator = PubmedIngestCoordinatorService.new(config, ingest_tracker)
  # coordinator.run
end

desc 'Ingest new PubMed PDFs from the backlog and attach them to Hyrax works if matched'
task :pubmed_backlog_ingest, [:file_retrieval_directory, :output_dir, :admin_set_title] => :environment do |task, args|
  return unless valid_args('pubmed_ingest', args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title])
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                             args[:file_retrieval_directory] :
                             Rails.root.join(args[:file_retrieval_directory])
  coordinator = Tasks::PubmedIngest::Backlog::PubmedIngestCoordinatorService.new({
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => DEPOSITOR,
    'file_retrieval_directory' => file_retrieval_directory,
    'output_dir' => args[:output_dir]
  })
  res = coordinator.run
end

def build_pubmed_ingest_config_and_tracker(args: nil, env: nil)
  input = args || env
  from_env = env.present?

  start_date = from_env ? ENV['PUBMED_INGEST_START_DATE'] : input[:start_date]
  admin_set_title = from_env ? ENV['PUBMED_INGEST_ADMIN_SET_TITLE'] : input[:admin_set_title]

  unless start_date && admin_set_title
    puts "❌ Required: START_DATE and ADMIN_SET_TITLE"
    puts "💡 Run `rake pubmed_ingest_help` for usage."
    exit(1)
  end

  resume_flag = ActiveModel::Type::Boolean.new.cast(from_env ? ENV['PUBMED_INGEST_RESUME'] : input[:resume])
  force_overwrite = ActiveModel::Type::Boolean.new.cast(from_env ? ENV['PUBMED_INGEST_FORCE_OVERWRITE'] : input[:force_overwrite])
  end_date = from_env ? ENV['PUBMED_INGEST_END_DATE'] : input[:end_date]
  script_start_time = Time.now

  if resume_flag && force_overwrite
    puts "❌ You cannot set both RESUME=true and FORCE_OVERWRITE=true."
    puts "💡 Use RESUME=true to continue an existing ingest, or FORCE_OVERWRITE=true to restart."
    exit(1)
  end

  parsed_start = Date.parse(start_date)
  parsed_end = end_date.present? ? Date.parse(end_date) : Date.today

  raw_output_dir = from_env ? ENV['PUBMED_INGEST_OUTPUT_DIR'] : input[:output_dir]
  output_dir = if raw_output_dir
                 path = Pathname.new(raw_output_dir)
                 path.absolute? ? path : Rails.root.join(path)
               else
                 Rails.root.join('tmp')
               end

  output_dir = output_dir.join("pubmed_ingest_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")

  config = {
    'start_date' => parsed_start,
    'end_date' => parsed_end,
    'admin_set_title' => admin_set_title,
    'depositor_onyen' => DEPOSITOR,
    'output_dir' => output_dir.to_s,
    'time' => script_start_time,
  }

  FileUtils.mkdir_p(output_dir)
  write_intro_banner(config: config)

  tracker = Tasks::PubmedIngest::SharedUtilities::IngestTracker.build(
    config: config,
    resume: resume_flag,
    force_overwrite: force_overwrite
  )

  [config, tracker]
end

def valid_args(function_name, *args)
  if args.any?(&:nil?)
    puts "❌ #{function_name}: One or more required arguments are missing."
    return false
    end

  true
end

def write_intro_banner(config:)
  banner_lines = [
    '=' * 80,
    '  PubMed Ingest',
    '-' * 80,
    "  Start Time: #{config['time'].strftime('%Y-%m-%d %H:%M:%S')}",
    "  Output Dir: #{config['output_dir']}",
    "  Depositor:  #{config['depositor_onyen']}",
    "  Admin Set:  #{config['admin_set_title']}",
    "  Date Range: #{config['start_date']} to #{config['end_date']}",
    '=' * 80
  ]
  banner_lines.each do |line|
    puts line
    Rails.logger.info(line)
  end
end
