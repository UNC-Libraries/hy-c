# frozen_string_literal: true
desc 'Ingest new PDFs from the NSF backlog and attach them to Hyrax works if matched'
task :nsf_backlog_ingest, [:resume, :file_info_csv_path, :file_retrieval_directory, :output_dir, :admin_set_title, :depositor_onyen] => :environment do |task, args|
  return unless valid_args([args[:resume], args[:file_info_csv_path], args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title], args[:depositor_onyen]])
  config = build_config(args)
  config['output_dir'] = resolve_output_directory(args, config)
  coordinator = Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService.new(config)
  res = coordinator.run
end

def valid_args(args)
  missing_args = []
  missing_args << 'resume' if args[0].nil?
  missing_args << 'file_info_csv_path' if args[1].nil?
  missing_args << 'file_retrieval_directory' if args[2].nil?
  missing_args << 'output_dir' if args[3].nil?
  missing_args << 'admin_set_title' if args[4].nil?
  missing_args << 'depositor_onyen' if args[5].nil?
  unless missing_args.empty?
    puts "❌ Missing required arguments: #{missing_args.join(', ')}"
    exit(1)
  end
  true
end

def build_config(args)
  resume = ActiveModel::Type::Boolean.new.cast(args[:resume])
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                               args[:file_retrieval_directory] :
                               Rails.root.join(args[:file_retrieval_directory])
  output_directory = Pathname.new(args[:output_dir]).absolute? ?
                               args[:output_dir] :
                                  Rails.root.join(args[:output_dir])
  config = {
    'time' => resume ? nil : Time.now,
    'restart_time' => resume ? Time.now : nil,
    'resume' => ActiveModel::Type::Boolean.new.cast(args[:resume]),
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => args[:depositor_onyen],
    'output_dir' => output_directory,
    'file_retrieval_directory' => file_retrieval_directory,
    'file_info_csv_path' => args[:file_info_csv_path]
  }
  write_intro_banner(config: config)
  config
 rescue ArgumentError => e
   puts "❌ Invalid date format: #{e.message}"
   exit(1)
end

def resolve_output_directory(args, config)
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
    timestamp = config['time'].strftime('%Y%m%d_%H%M%S')
    output_dir = File.join(output_dir, "nsf_backlog_ingest_#{timestamp}")
      # Create the directory if it doesn't exist
    Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
    output_dir = File.expand_path(output_dir)
  end

  output_dir
end

def write_intro_banner(config:)
  time_banner = config['time'] ?
        "  Start Time: #{config['time'].strftime('%Y-%m-%d %H:%M:%S')}" :
        "  Restart Time: #{config['restart_time'].strftime('%Y-%m-%d %H:%M:%S')}"

  banner_lines = [
    '=' * 80,
    '  NSF Ingest',
    '-' * 80,
     time_banner,
    "  Output Dir: #{config['output_dir']}",
    "  File Retrieval Dir: #{config['file_retrieval_directory']}",
    "  File Info CSV: #{config['file_info_csv_path']}",
    "  Depositor:  #{config['depositor_onyen']}",
    "  Admin Set:  #{config['admin_set_title']}",
    '=' * 80
  ]
  banner_lines.each { |line| puts(line); Rails.logger.info(line) }
end
