# frozen_string_literal: true
desc 'Ingest new PDFs from the NSF backlog and attach them to Hyrax works if matched'
task :nsf_backlog_ingest, [:resume, :file_info_csv_path, :file_retrieval_directory, :output_dir, :admin_set_title, :depositor_onyen] => :environment do |task, args|
  now = Time.now
  resume = ActiveModel::Type::Boolean.new.cast(args[:resume])
  validate_args!(args) unless resume

  output_directory = resolve_output_directory(args, now)
  tracker = resume ? retrieve_tracker_json(output_directory) : nil
  config = build_config(args, tracker, output_directory, now)

  # config['output_dir'] = resolve_output_directory(args, config)
  coordinator = Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService.new(config)
  res = coordinator.run
end

def validate_args!(args)
  required = %i[file_info_csv_path file_retrieval_directory output_dir admin_set_title depositor_onyen]
  missing = required.select { |key| args[key].nil? }

  unless missing.empty?
    puts "❌ Missing required arguments: #{missing.join(', ')}"
    exit(1)
  end
end

def build_config(args, tracker, output_dir, now)
  resume = ActiveModel::Type::Boolean.new.cast(args[:resume])
  config = if resume
             {
               'start_time' => tracker['start_time'],
               'restart_time' => now,
               'admin_set_title' => tracker['admin_set_title'],
               'depositor_onyen' => tracker['depositor_onyen'],
               'output_dir' => tracker['output_dir'],
               'file_retrieval_directory' => tracker['file_retrieval_directory'],
               'file_info_csv_path' => tracker['file_info_csv_path']
             }
           else
             {
               'start_time' => now,
               'resume' => false,
               'admin_set_title' => args[:admin_set_title],
               'depositor_onyen' => args[:depositor_onyen],
               'output_dir' => output_dir,
               'file_retrieval_directory' => normalize_path(args[:file_retrieval_directory]),
               'file_info_csv_path' => normalize_path(args[:file_info_csv_path])
             }
           end
  config = {
    'time' => resume ? tracker['start_time'] : now,
    'restart_time' => resume ? now : tracker['restart_time'],
    'resume' => ActiveModel::Type::Boolean.new.cast(args[:resume]),
    'admin_set_title' => resume ? tracker['admin_set_title'] : args[:admin_set_title],
    'depositor_onyen' => resume ? tracker['depositor_onyen'] : args[:depositor_onyen],
    'output_dir' => resume ? tracker['output_dir'] : output_dir,
    'file_retrieval_directory' => resume ? tracker['file_retrieval_directory'] : file_retrieval_directory,
    'file_info_csv_path' => resume ? tracker['file_info_csv_path'] : normalize_path(args[:file_info_csv_path])
  }
  write_intro_banner(config: config)
  config
 rescue ArgumentError => e
   puts "❌ Invalid date format: #{e.message}"
   exit(1)
end

def retrieve_tracker_json(output_dir)
  tracker_path = File.join(output_dir, Tasks::IngestHelperUtils::BaseIngestTracker::TRACKER_FILENAME)
  unless File.exist?(tracker_path)
    puts "❌ Tracker file not found at #{tracker_path}"
    exit(1)
  end
  JsonFileUtilsHelper.read_json_file(tracker_path)
end

def normalize_path(path)
  Pathname.new(path).absolute? ? path : Rails.root.join(path)
end

def resolve_output_directory(args, time)
  output_dir = args[:output_dir]

  if args[:resume].to_s.downcase == 'true'
     #  Use latest NSF output path if provided a wildcard — e.g., "nsf_output/*"
    if output_dir.include?('*')
      expanded = Dir.glob(output_dir)
                    .select { |f| File.directory?(f) && File.basename(f).start_with?('nsf_backlog_ingest_') }

      if expanded.empty?
        puts "❌ No matching NSF ingest directories found for pattern '#{output_dir}'"
        exit(1)
      end

      # pick the newest by modification time
      latest = expanded.max_by { |path| File.mtime(path) }
      LogUtilsHelper.double_log("Using latest NSF ingest directory: #{latest}", :info, tag: 'NSFIngestCoordinator')
      return File.expand_path(latest)
    end

    unless Dir.exist?(output_dir)
      puts "❌ The specified output_dir '#{output_dir}' does not exist."
      exit(1)
    end

    # No wildcard — validate provided dir
    output_dir_basename = File.basename(output_dir)
    unless output_dir_basename.start_with?('nsf_backlog_ingest_')
      puts "❌ When resuming, the output_dir must match the format 'nsf_backlog_ingest_YYYYMMDD_HHMMSS'"
      exit(1)
    end

  else
    # Create a new timestamped directory when not resuming
    timestamp = time.strftime('%Y%m%d_%H%M%S')
    output_dir = File.join(output_dir, "nsf_backlog_ingest_#{timestamp}")
      # Create the directory if it doesn't exist
    Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
    output_dir = File.expand_path(output_dir)
  end

  normalize_path(output_dir)
end

def write_intro_banner(config:)
  mode_label = config['resume'] ? 'RESUME RUN' : 'NEW RUN'
  time_label = config['resume'] ? 'Restart Time' : 'Start Time'
  time_value = config['resume'] ? config['restart_time'] : config['start_time']

  banner_lines = [
    '=' * 80,
    "  NSF Ingest (#{mode_label})",
    '-' * 80,
    "  #{time_label}: #{time_value.strftime('%Y-%m-%d %H:%M:%S')}",
    "  Output Dir: #{config['output_dir']}",
    "  File Retrieval Dir: #{config['file_retrieval_directory']}",
    "  File Info CSV: #{config['file_info_csv_path']}",
    "  Depositor:  #{config['depositor_onyen']}",
    "  Admin Set:  #{config['admin_set_title']}",
    '=' * 80
  ]
  banner_lines.each { |line| puts(line); Rails.logger.info(line) }
end
