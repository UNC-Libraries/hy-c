# frozen_string_literal: true
# Notes:
# 1. Script uses PMC-OAI API to retrieve metadata and make comparisons of alternate IDs. (PMCID, PMID)
# 2. PMC requests scripts making >100 requests be ran outside of peak hours. (5 AM - 9 PM)
DEPOSITOR = ENV['PUBMED_INGEST_DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
SUBDIRS = %w[01_build_id_lists 02_load_and_ingest_metadata 03_attach_files_to_works]
REQUIRED_ARGS = %w[start_date end_date admin_set_title]

desc 'Ingest works from the PubMed API'
task :pubmed_ingest, [:start_date, :end_date, :admin_set_title, :output_dir, :full_text_dir] => :environment do |t, args|
  # This version of the task will be called with arguments in the order specified in the task definition.
  # For example: rake 'pubmed_ingest[2024-01-01,2024-01-31,default]'
  
  options = {}
  options[:start_date] = args[:start_date]
  options[:end_date] = args[:end_date]
  options[:admin_set_title] = args[:admin_set_title]
  options[:output_dir] = args[:output_dir]
  options[:full_text_dir] = args[:full_text_dir]
  options[:depositor_onyen] = ENV['PUBMED_INGEST_DIMENSIONS_INGEST_DEPOSITOR_ONYEN']

  puts "Starting PubMed ingest with options: #{options.inspect}"

  # Forward to shared logic
  config, tracker = build_pubmed_ingest_config_and_tracker(args: options)

  # Uncomment these when ready to actually run the coordinator
  coordinator = Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService.new(config, tracker)
  coordinator.run
end

desc 'Ingest new PubMed PDFs from the backlog and attach them to Hyrax works if matched'
task :pubmed_backlog_ingest, [:file_retrieval_directory, :output_dir, :admin_set_title] => :environment do |task, args|
  return unless valid_args('pubmed_ingest', args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title])
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                             args[:file_retrieval_directory] :
                             Rails.root.join(args[:file_retrieval_directory])
  coordinator = Tasks::PubmedIngest::Backlog::PubmedIngestCoordinatorService.new({
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => args[:depositor_onyen],
    'file_retrieval_directory' => file_retrieval_directory,
    'output_dir' => args[:output_dir]
  })
  res = coordinator.run
end

def build_pubmed_ingest_config_and_tracker(args:)
  depositor = 'admin'
  resume_flag    = ActiveModel::Type::Boolean.new.cast(args[:resume])
  raw_output_dir = args[:output_dir]
  script_start_time = Time.now
  output_dir = nil
  config = {}

  if resume_flag
    if raw_output_dir.blank?
      puts '❌ You cannot resume an ingest without specifying an output directory.'
      exit(1)
    end

    output_dir = Pathname.new(raw_output_dir)
    unless output_dir.directory?
      puts "❌ Output directory does not exist or is not a directory: #{output_dir}"
      exit(1)
    end

    tracker_path = output_dir.join('ingest_tracker.json')
    unless tracker_path.exist?
      puts "❌ Tracker file not found: #{tracker_path}"
      exit(1)
    end

    # config = {
    #   'start_date'     => Date.parse(tracker['date_range']['start']),
    #   'end_date'       => Date.parse(tracker['date_range']['end']),
    #   'admin_set_title'=> tracker['admin_set_title'],
    #   'depositor_onyen'=> tracker['depositor_onyen'],
    #   'output_dir'     => output_dir.to_s,
    #   'time'           => Time.parse(tracker['restart_time'] || tracker['start_time']),
    #   'full_text_dir'  => tracker['full_text_dir'],
    # }

    config = {
      'output_dir'      => output_dir.to_s,
      'restart_time'   => script_start_time
    }

    tracker = Tasks::PubmedIngest::SharedUtilities::IngestTracker.build(
      config: config,
      resume: true
    )
    config['full_text_dir'] = tracker['full_text_dir'] if tracker['full_text_dir'].present?
    unless tracker
      puts '❌ Failed to load existing tracker.'
      exit(1)
    end



  else
    REQUIRED_ARGS.each do |key|
      if args[key.to_sym].blank?
        puts "❌ Missing required option: --#{key.tr('_', '-')}"
        exit(1)
      end
    end

    begin
      parsed_start = Date.parse(args[:start_date])
      parsed_end   = Date.parse(args[:end_date])
    rescue ArgumentError => e
      puts "❌ Invalid date format: #{e.message}"
      exit(1)
    end

    admin_set = AdminSet.where(title_tesim: args[:admin_set_title]).first
    unless admin_set
      puts "❌ Admin Set not found: #{args[:admin_set_title]}"
      exit(1)
    end

    # Output directory handling
    output_dir = resolve_output_dir(raw_output_dir, script_start_time)
    full_text_dir = resolve_full_text_dir(args[:full_text_dir], output_dir, script_start_time)

    # Create necessary directories
    FileUtils.mkdir_p(output_dir)
    SUBDIRS.each do |dir|
      FileUtils.mkdir_p(output_dir.join(dir))
    end
    FileUtils.mkdir_p(full_text_dir)

    config = {
      'start_date'      => parsed_start,
      'end_date'        => parsed_end,
      'admin_set_title' => args[:admin_set_title],
      'depositor_onyen' => depositor,
      'output_dir'      => output_dir.to_s,
      'time'            => script_start_time,
      'full_text_dir'   => full_text_dir.to_s
    }

    write_intro_banner(config: config)
    tracker = Tasks::PubmedIngest::SharedUtilities::IngestTracker.build(
    config: config,
    resume: resume_flag
  )
  end

  [config, tracker]
end

def valid_args(function_name, *args)
  if args.any?(&:nil?)
    puts "❌ #{function_name}: One or more required arguments are missing."
    return false
    end

  true
end

def resolve_output_dir(raw_output_dir, script_start_time)
  if raw_output_dir.present?
    base_dir = Pathname.new(raw_output_dir)
    base_dir = Rails.root.join(base_dir) unless base_dir.absolute?
    base_dir.join("pubmed_ingest_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
  else
    LogUtilsHelper.double_log('No output directory specified. Using default tmp directory.', :info, tag: 'PubMed Ingest')
    Rails.root.join('tmp', "pubmed_ingest_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
  end
end

def resolve_full_text_dir(raw_full_text_dir, output_dir, script_start_time)
  if raw_full_text_dir.present?
    base = Pathname.new(raw_full_text_dir)
    base.absolute? ? base : Rails.root.join(base)
  else
    default_dir = output_dir.join("full_text_pdfs_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
    LogUtilsHelper.double_log("No full-text directory specified. Using default: #{default_dir}", :info, tag: 'PubMed Ingest')
    default_dir
  end
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
