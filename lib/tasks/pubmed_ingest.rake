# frozen_string_literal: true
# Notes:
# 1. Script uses PMC-OAI API to retrieve metadata and make comparisons of alternate IDs. (PMCID, PMID)
# 2. PMC requests scripts making >100 requests be ran outside of peak hours. (5 AM - 9 PM)
DEPOSITOR = ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
TRACKER_FILENAME = 'ingest_tracker.json'
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

desc 'Ingest works from the PubMed API within the specified date range'
task :pubmed_ingest, [:start_date, :end_date, :admin_set_title, :resume, :output_dir, :force_overwrite] => :environment do |task, args|
  return unless valid_args('pubmed_ingest', args[:start_date], args[:admin_set_title])
  # WIP: Hardcode time for testing purposes (Remove Later)
  # script_start_time = Time.now
  script_start_time = Time.parse('2023-10-01 12:00:00')
  start_date = Date.parse(args[:start_date])
  end_date = args[:end_date].present? ? Date.parse(args[:end_date]) : Date.today
  admin_set_title = args[:admin_set_title]
  output_dir = args[:output_dir].present? ?
               Pathname.new(args[:output_dir]).absolute? : Rails.root.join('tmp')
  output_dir = output_dir.join("pubmed_ingest_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
  resume_flag = ActiveModel::Type::Boolean.new.cast(args[:resume])
  force_overwrite = ActiveModel::Type::Boolean.new.cast(args[:force_overwrite])
  config = {
    'start_date' => start_date,
    'end_date' => end_date,
    'admin_set_title' => admin_set_title,
    'depositor_onyen' => DEPOSITOR,
    'output_dir' => output_dir.to_s,
    'time' => script_start_time
  }
  write_intro_banner(config: config)
  FileUtils.mkdir_p(output_dir)

  if resume_flag
    LogUtilsHelper.double_log('Resume flag is set. Attempting to resume PubMed ingest from previous state.', :info, tag: 'PubMed Ingest')
    previous_state = Tasks::PubmedIngest::SharedUtilities::TrackerHelper.load_tracker(config)

    if previous_state
      previous_state['restart_time'] = config['time'].strftime('%Y-%m-%d %H:%M:%S')
      config.merge!(previous_state)
      LogUtilsHelper.double_log("Resuming from existing state: #{previous_state}", :info, tag: 'PubMed Ingest')
    else
      LogUtilsHelper.double_log('No valid state found. Initializing new ingest tracker.', :warn, tag: 'PubMed Ingest')
      Tasks::PubmedIngest::SharedUtilities::TrackerHelper.init_tracker(config)
    end
  else
    LogUtilsHelper.double_log('Resume flag is not set. Initializing new ingest tracker.', :info, tag: 'PubMed Ingest')
    Tasks::PubmedIngest::SharedUtilities::TrackerHelper.check_tracker_overwrite!(config, force_overwrite: force_overwrite)
    Tasks::PubmedIngest::SharedUtilities::TrackerHelper.init_tracker(config)
  end

  # coordinator = Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService.new(config)
  # res = coordinator.run
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
