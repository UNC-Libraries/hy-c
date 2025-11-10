# frozen_string_literal: true
module Tasks
  module IngestHelperUtils
    module RakeTaskHelper
      def validate_args!(args, required_keys)
        missing = required_keys.select { |key| args[key].nil? }
        return if missing.empty?

        puts "❌ Missing required arguments: #{missing.join(', ')}"
        exit(1)
      end

      def normalize_path(path)
        Pathname.new(path).absolute? ? path : Rails.root.join(path)
      end

      def retrieve_tracker_json(output_dir)
        tracker_path = File.join(output_dir, Tasks::IngestHelperUtils::BaseIngestTracker::TRACKER_FILENAME)
        unless File.exist?(tracker_path)
          puts "❌ Tracker file not found at #{tracker_path}"
          exit(1)
        end
        JsonFileUtilsHelper.read_json(tracker_path)
      end

      def resolve_output_directory(args, time, prefix: 'backlog_ingest')
        output_dir = args[:output_dir]

        if args[:resume].to_s.downcase == 'true'
          return resolve_resume_directory(output_dir, prefix)
        end

        create_new_output_directory(output_dir, time, prefix)
      end

      def write_intro_banner(config:, ingest_type:, additional_fields: {})
        mode_label = config['resume'] ? 'RESUME RUN' : 'NEW RUN'
        time_label = config['resume'] ? 'Restart Time' : 'Start Time'
        time_value = config['resume'] ? config['restart_time'] : config['start_time']

        banner_lines = [
          '=' * 80,
          "  #{ingest_type} Ingest (#{mode_label})",
          '-' * 80,
          "  #{time_label}: #{time_value.strftime('%Y-%m-%d %H:%M:%S')}",
          "  Output Dir: #{config['output_dir']}",
          "  File Retrieval Dir: #{config['full_text_dir']}"
        ]

        # Add any additional fields (like file_info_csv_path for NSF)
        additional_fields.each do |label, key|
          banner_lines << "  #{label}: #{config[key]}" if config[key].present?
        end

        banner_lines += [
          "  Depositor:  #{config['depositor_onyen']}",
          "  Admin Set:  #{config['admin_set_title']}",
          '=' * 80
        ]

        banner_lines.each { |line| puts(line); Rails.logger.info(line) }
      end

      private

      def resolve_resume_directory(output_dir, prefix)
        if output_dir.include?('*')
          expanded = Dir.glob(output_dir).select { |f| File.directory?(f) && File.basename(f).start_with?("#{prefix}_") }
          if expanded.empty?
            puts "❌ No matching ingest directories found for pattern '#{output_dir}'"
            exit(1)
          end

          latest = expanded.max_by { |path| File.mtime(path) }
          LogUtilsHelper.double_log("Using latest ingest directory: #{latest}", :info, tag: 'IngestCoordinator')
          return File.expand_path(latest)
        end

        unless Dir.exist?(output_dir)
          puts "❌ The specified output_dir '#{output_dir}' does not exist."
          exit(1)
        end

        basename = File.basename(output_dir)
        unless basename.start_with?("#{prefix}_")
          puts "❌ When resuming, output_dir must match '#{prefix}_YYYYMMDD_HHMMSS'"
          exit(1)
        end

        File.expand_path(output_dir)
      end

      def create_new_output_directory(output_dir, time, prefix)
        timestamp = time.strftime('%Y%m%d_%H%M%S')
        new_dir = File.join(output_dir, "#{prefix}_#{timestamp}")
        FileUtils.mkdir_p(new_dir)
        File.expand_path(new_dir)
      end
    end
  end
end