# frozen_string_literal: true
# Notes:
# 1. Script uses PMC-OAI API to retrieve metadata and make comparisons of alternate IDs. (PMCID, PMID)
# 2. PMC requests scripts making >100 requests be ran outside of peak hours. (5 AM - 9 PM)
DEPOSITOR = ENV['PUBMED_INGEST_DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
desc 'Ingest works from the PubMed API'
task 'pubmed_ingest' => :environment do
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: bundle exec rake pubmed_ingest -- [options]'

    opts.on('--start-date DATE', 'Start date for ingest (required)') { |v| options[:start_date] = v }
    opts.on('--end-date DATE', 'End date for ingest (optional)') { |v| options[:end_date] = v }
    opts.on('--admin-set-title TITLE', 'Admin Set title (required)') { |v| options[:admin_set_title] = v }
    opts.on('--resume [BOOLEAN]', 'Resume from tracker file (optional, automatically detected in specified output directory)') do |val|
      options[:resume] = ActiveModel::Type::Boolean.new.cast(val)
    end
    opts.on('--force-overwrite [BOOLEAN]', 'Force overwrite of tracker file (optional)') do |val|
      options[:force_overwrite] = ActiveModel::Type::Boolean.new.cast(val)
    end
    opts.on('--output-dir DIR', 'Output directory (optional)') { |v| options[:output_dir] = v }
    opts.on('-h', '--help', 'Display help') do
      puts opts
      exit
    end
  end

  # Create a copy of ARGV and clean it up
  args_to_parse = ARGV.dup

  # Remove task name if it's the first argument
  args_to_parse.shift if args_to_parse.first == 'pubmed_ingest'

  # Remove '--' separator if it's present
  args_to_parse.shift if args_to_parse.first == '--'

    # Detect help flag early
  if args_to_parse.include?('--help') || args_to_parse.include?('-h')
    puts parser
    exit
  end


  begin
    parser.parse!(args_to_parse)
  rescue OptionParser::ParseError => e
    puts "❌ #{e.message}"
    puts parser
    exit(1)
  end

  puts "Starting PubMed ingest with options: #{options.inspect}"

  # Forward to shared logic
  config, tracker = build_pubmed_ingest_config_and_tracker(args: options)

  # Uncomment these when ready to actually run the coordinator
  # coordinator = PubmedIngestCoordinatorService.new(config, tracker)
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

def build_pubmed_ingest_config_and_tracker(args:)
  # Extract values
  start_date       = args[:start_date]
  end_date         = args[:end_date]
  admin_set_title  = args[:admin_set_title]
  resume_flag      = ActiveModel::Type::Boolean.new.cast(args[:resume])
  force_overwrite  = ActiveModel::Type::Boolean.new.cast(args[:force_overwrite])
  raw_output_dir   = args[:output_dir]

  # Required check
  unless start_date && admin_set_title
    puts '❌ Required: --start-date and --admin-set-title'
    puts "Provided: start-date=#{start_date}, admin-set-title=#{admin_set_title}"
    exit(1)
  end

  # Conflict check
  if resume_flag && force_overwrite
    puts '❌ You cannot set both --resume=true and --force-overwrite=true.'
    puts '💡 Use --resume=true to continue an ingest, or --force-overwrite=true to restart.'
    exit(1)
  end

  if resume_flag && raw_output_dir.blank?
    puts '❌ You cannot resume an ingest without specifying an output directory.'
    puts '💡 Use --output-dir to specify where the tracker file is located.'
    exit(1)
  end

  # Parse dates
  script_start_time = Time.now
  begin
    parsed_start = Date.parse(start_date)
  rescue ArgumentError
    puts "❌ Invalid start date format: #{start_date}"
    exit(1)
  end

  parsed_end = if end_date.present?
                 begin
                   Date.parse(end_date)
                 rescue ArgumentError
                   puts "❌ Invalid end date format: #{end_date}"
                   exit(1)
                 end
               else
                 Date.today
               end

  # Build output path
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
