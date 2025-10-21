# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService
  include Tasks::IngestHelperUtils::IngestHelper
  BUILD_ID_LISTS_OUTPUT_DIR = '01_build_id_lists'
  LOAD_METADATA_OUTPUT_DIR  = '02_load_and_ingest_metadata'
  ATTACH_FILES_OUTPUT_DIR   = '03_attach_files_to_works'
  RESULT_CSV_OUTPUT_DIR      = '04_generate_result_csvs'
  SUBDIRS                   = [BUILD_ID_LISTS_OUTPUT_DIR, LOAD_METADATA_OUTPUT_DIR, ATTACH_FILES_OUTPUT_DIR, RESULT_CSV_OUTPUT_DIR].freeze
  REQUIRED_ARGS             = %w[start_date end_date admin_set_title].freeze
  MAX_ROWS = 100

  def initialize(config, tracker)
    @config = config
    @tracker = tracker
    @id_list_output_directory = File.join(config['output_dir'], BUILD_ID_LISTS_OUTPUT_DIR)
    @metadata_ingest_output_directory = File.join(config['output_dir'], LOAD_METADATA_OUTPUT_DIR)
    @result_output_directory = File.join(config['output_dir'], RESULT_CSV_OUTPUT_DIR)

    @file_attachment_results_path = File.join(config['output_dir'], ATTACH_FILES_OUTPUT_DIR, 'attachment_results.jsonl')
    @metadata_ingest_results_path = File.join(@metadata_ingest_output_directory, 'metadata_ingest_results.jsonl')
    @final_ingest_results_path = File.join(@config['output_dir'], 'final_ingest_results.json')
    @generated_results_csv_dir = File.join(@config['output_dir'], RESULT_CSV_OUTPUT_DIR)
  end

  def run
    build_id_lists
     # Suppress emails during metadata ingest and file attachment in production to avoid spam
    NotificationUtilsHelper.suppress_emails do
      load_and_ingest_metadata
      attach_files
    end
    format_results_and_notify
    delete_full_text_pdfs(config: @config)
    LogUtilsHelper.double_log('PubMed ingest workflow completed successfully.', :info, tag: 'PubmedIngestCoordinator')
    rescue => e
      LogUtilsHelper.double_log("PubMed ingest workflow failed: #{e.message}", :error, tag: 'PubmedIngestCoordinator')
      raise e
  end

  private

  def attach_files
    if @tracker['progress']['attach_files_to_works']['completed']
      LogUtilsHelper.double_log('Skipping file attachment as it is already completed.', :info, tag: 'attach_files')
      return
    end
    begin
      LogUtilsHelper.double_log('Starting file attachment process...', :info, tag: 'attach_files')
      file_attachment_service = Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService.new(
        config: @config,
        tracker: @tracker,
        log_file_path: @file_attachment_results_path,
        full_text_path: @config['full_text_dir'],
        metadata_ingest_result_path: @metadata_ingest_results_path
      )

      file_attachment_service.run

      @tracker['progress']['attach_files_to_works']['completed'] = true
      @tracker.save

    rescue => e
      LogUtilsHelper.double_log("File attachment failed: #{e.message}", :error, tag: 'attach_files')
      raise e
    end
    LogUtilsHelper.double_log('File attachment process completed.', :info, tag: 'attach_files')
  end

  def load_and_ingest_metadata
    md_ingest_service = Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService.new(
      config: @config,
      tracker: @tracker,
      md_ingest_results_path: @metadata_ingest_results_path,
    )
    ['pubmed', 'pmc'].each do |db|
      if @tracker['progress']['metadata_ingest'][db]['completed']
        LogUtilsHelper.double_log("Skipping metadata ingest for #{db} as it is already completed.", :info, tag: 'load_and_ingest_metadata')
        next
      end
      begin
        md_ingest_service.load_alternate_ids_from_file(path: File.join(@id_list_output_directory, "#{db}_alternate_ids.jsonl"))
        md_ingest_service.batch_retrieve_and_process_metadata(db: db)
        @tracker['progress']['metadata_ingest'][db]['completed'] = true
        @tracker.save
        rescue => e
          LogUtilsHelper.double_log("Metadata ingest failed: #{e.message}", :error, tag: 'load_and_ingest_metadata')
          raise e
      end

      LogUtilsHelper.double_log("Metadata ingest for #{db} completed successfully.", :info, tag: 'load_and_ingest_metadata')
      LogUtilsHelper.double_log("Output directory: #{@metadata_ingest_output_directory}", :info, tag: 'load_and_ingest_metadata')
    end
  end

  def build_id_lists
    id_retrieval_service = Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService.new(
      start_date: @config['start_date'],
      end_date: @config['end_date'],
      tracker: @tracker
    )
    ['pubmed', 'pmc'].each do |db|
      completed = @tracker['progress']['retrieve_ids_within_date_range'][db]['completed']
      if completed
        LogUtilsHelper.double_log("Skipping ID retrieval for #{db} as it is already completed.", :info, tag: 'build_id_lists')
        next
      end

      LogUtilsHelper.double_log("Retrieving record IDs for PubMed and PMC databases within the date range: #{@config['start_date'].strftime('%Y-%m-%d')} - #{@config['end_date'].strftime('%Y-%m-%d')}", :info, tag: 'build_id_lists')
      record_id_path = File.join(@id_list_output_directory, "#{db}_ids.jsonl")
      id_retrieval_service.retrieve_ids_within_date_range(output_path: record_id_path, db: db)
      @tracker['progress']['retrieve_ids_within_date_range'][db]['completed'] = true
      @tracker.save
    end

    ['pubmed', 'pmc'].each do |db|
      completed = @tracker['progress']['stream_and_write_alternate_ids'][db]['completed']
      if completed
        LogUtilsHelper.double_log("Skipping alternate ID retrieval for #{db} as it is already completed.", :info, tag: 'build_id_lists')
        next
      end
      record_id_path = File.join(@id_list_output_directory, "#{db}_ids.jsonl")
      LogUtilsHelper.double_log("Streaming and writing alternate IDs for the #{db} database.", :info, tag: 'build_id_lists')
      alternate_id_path = File.join(@id_list_output_directory, "#{db}_alternate_ids.jsonl")
      id_retrieval_service.stream_and_write_alternate_ids(input_path: record_id_path, output_path: alternate_id_path, db: db)
      @tracker['progress']['stream_and_write_alternate_ids'][db]['completed'] = true
      @tracker.save
    end

    id_retrieval_service.adjust_id_lists(
      pubmed_path: File.join(@id_list_output_directory, 'pubmed_alternate_ids.jsonl'),
      pmc_path: File.join(@id_list_output_directory, 'pmc_alternate_ids.jsonl')
    )
    LogUtilsHelper.double_log("ID lists built successfully. Output directory: #{@id_list_output_directory}", :info, tag: 'build_id_lists')
  end

  def format_results_and_notify
    notification_service = Tasks::PubmedIngest::Recurring::Utilities::NotificationService.new(
      config: @config,
      tracker: @tracker,
      log_file_path: @generated_results_csv_dir,
      file_attachment_results_path: @file_attachment_results_path,
      max_display_rows: MAX_ROWS
    )
    notification_service.run
    JsonFileUtilsHelper.write_json(@results, @final_ingest_results_path , pretty: true)
  end

  def self.build_pubmed_ingest_config_and_tracker(args:)
    depositor        = args[:depositor_onyen].presence || 'admin'
    resume_flag      = ActiveModel::Type::Boolean.new.cast(args[:resume])
    raw_output_dir   = args[:output_dir]
    raw_full_text_dir = args[:full_text_dir]
    script_start     = Time.now
    output_dir       = nil
    config           = {}

    if raw_output_dir.blank?
      puts '❌ You must specify an output directory.'
      exit(1)
    end

    if resume_flag
      output_dir = Pathname.new(resolve_output_dir(raw_output_dir, script_start, resume_flag))
      tracker_path = output_dir.join(Tasks::IngestHelperUtils::BaseIngestTracker::TRACKER_FILENAME)
      unless tracker_path.exist?
        puts "❌ Tracker file not found: #{tracker_path}"
        exit(1)
      end

      config = {
        'output_dir'   => output_dir.to_s,
        'restart_time' => script_start
      }

      tracker = Tasks::PubmedIngest::SharedUtilities::PubmedIngestTracker.build(
        config: config,
        resume: true
      )

      config['full_text_dir'] = tracker['full_text_dir']
      config['depositor_onyen'] = tracker['depositor_onyen']
      config['admin_set_title'] = tracker['admin_set_title']
      unless tracker
        puts '❌ Failed to load existing tracker.'
        exit(1)
      end
    else
      output_dir = Pathname.new(resolve_output_dir(raw_output_dir, script_start, resume_flag))
      if raw_full_text_dir.blank?
        puts '❌ You must specify a full text directory when not resuming.'
        exit(1)
      end

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

      full_text_dir = resolve_full_text_dir(args[:full_text_dir], output_dir, script_start)
      FileUtils.mkdir_p(output_dir)
      SUBDIRS.each { |dir| FileUtils.mkdir_p(output_dir.join(dir)) }
      FileUtils.mkdir_p(full_text_dir)

      config = {
        'start_date'      => parsed_start,
        'end_date'        => parsed_end,
        'admin_set_title' => args[:admin_set_title],
        'depositor_onyen' => depositor,
        'output_dir'      => output_dir.to_s,
        'time'            => script_start,
        'full_text_dir'   => full_text_dir.to_s
      }

      write_intro_banner(config: config)
      tracker = Tasks::PubmedIngest::SharedUtilities::PubmedIngestTracker.build(
        config: config,
        resume: resume_flag
      )
    end

    [config, tracker]
  end

  def self.resolve_output_dir(raw_output_dir, script_start_time, resume_flag)
    if raw_output_dir&.include?('*') && resume_flag
     #  Use latest Pubmed output path within a directory if provided a wildcard — e.g., "pubmed_output/*"
      expanded = Dir.glob(raw_output_dir)
                    .select { |f| File.directory?(f) && File.basename(f).start_with?('pubmed_ingest_') }

      if expanded.empty?
        puts "❌ No matching PubMed ingest directories found for pattern '#{raw_output_dir}'"
        exit(1)
      end

      # pick the newest by modification time
      latest = expanded.max_by { |path| File.mtime(path) }
      LogUtilsHelper.double_log("Using latest PubMed ingest directory: #{latest}", :info, tag: 'PubMedIngestCoordinator')
      return File.expand_path(latest)
    end

    if raw_output_dir.present?
      base_dir = Pathname.new(raw_output_dir)
      base_dir = Rails.root.join(base_dir) unless base_dir.absolute?
      base_dir.join("pubmed_ingest_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
    else
      LogUtilsHelper.double_log('No output directory specified. Using default tmp directory.', :info, tag: 'PubMed Ingest')
      Rails.root.join('tmp', "pubmed_ingest_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
    end
  end
  private_class_method :resolve_output_dir

  def self.resolve_full_text_dir(raw_full_text_dir, output_dir, script_start_time)
    base = Pathname.new(raw_full_text_dir)
    base = base.join("full_text_pdfs_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
    base.absolute? ? base : Rails.root.join(base)
  end
  private_class_method :resolve_full_text_dir

  def self.write_intro_banner(config:)
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
    banner_lines.each { |line| puts(line); Rails.logger.info(line) }
  end
  private_class_method :write_intro_banner
end
