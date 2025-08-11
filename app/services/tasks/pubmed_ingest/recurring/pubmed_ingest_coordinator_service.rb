# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService
  BUILD_ID_LISTS_OUTPUT_DIR = '01_build_id_lists'
  LOAD_METADATA_OUTPUT_DIR  = '02_load_and_ingest_metadata'
  ATTACH_FILES_OUTPUT_DIR    = '03_attach_files_to_works'
  SUBDIRS                   = [BUILD_ID_LISTS_OUTPUT_DIR, LOAD_METADATA_OUTPUT_DIR, ATTACH_FILES_OUTPUT_DIR].freeze
  REQUIRED_ARGS             = %w[start_date end_date admin_set_title].freeze

  def initialize(config, tracker)
    @config = config
    @tracker = tracker
    @depositor_onyen = config['depositor_onyen']
    @results = {
      skipped: [],
      successfully_attached: [],
      successfully_ingested: [],
      headers: {
        total_unique_records: 0
      },
      failed: [],
      time: Time.now,
      depositor: config['depositor_onyen'],
      output_dir: config['output_dir'],
      admin_set: config['admin_set_title'],
      counts: {
        skipped: 0,
        successfully_attached: 0,
        successfully_ingested: 0,
        failed: 0
      }
    }
    @output_dir = config['output_dir']
    @id_list_output_directory = File.join(@output_dir, BUILD_ID_LISTS_OUTPUT_DIR)
    @metadata_ingest_output_directory = File.join(@output_dir, LOAD_METADATA_OUTPUT_DIR)
    @attachment_output_directory = File.join(@output_dir, ATTACH_FILES_OUTPUT_DIR)
    @full_text_dir    = config['full_text_dir']
    @admin_set_title  = config['admin_set_title']
    @start_date       = config['start_date']
    @end_date         = config['end_date']

    @results[:full_text_dir] = @full_text_dir
    @results[:start_date]    = @start_date.strftime('%Y-%m-%d') if @start_date
    @results[:end_date]      = @end_date.strftime('%Y-%m-%d')   if @end_date
  end

  def run
    build_id_lists
    load_and_ingest_metadata
    attach_files
    load_results
    finalize_report_and_notify(@results)
    JsonFileUtils.write_json(@results, File.join(@output_dir, 'ingest_results.json'), pretty: true)

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
        output_path: @attachment_output_directory,
        full_text_path: @config['full_text_dir'],
        metadata_ingest_result_path: File.join(@metadata_ingest_output_directory, 'metadata_ingest_results.jsonl'),
      )
      file_attachment_service.run
      @tracker['progress']['attach_files_to_works']['completed'] = true
      @tracker.save

    rescue => e
      LogUtilsHelper.double_log("File attachment failed: #{e.message}", :error, tag: 'attach_files') # << log exact format
      raise e
    end
    LogUtilsHelper.double_log('File attachment process completed.', :info, tag: 'attach_files')
  end

  def load_and_ingest_metadata
    md_ingest_service = Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService.new(
      config: @config,
      results: @results,
      tracker: @tracker,
      results_path: File.join(@metadata_ingest_output_directory, 'metadata_ingest_results.jsonl'),
    )
    ['pubmed', 'pmc'].each do |db|
      if @tracker['progress']['metadata_ingest'][db]['completed']
        LogUtilsHelper.double_log("Skipping metadata ingest for #{db} as it is already completed.", :info, tag: 'load_and_ingest_metadata')
        next
      end
      begin
        md_ingest_service.load_alternate_ids_from_file(path: File.join(@id_list_output_directory, "#{db}_alternate_ids.jsonl"))
        # WIP: Temporarily limit number of batches for testing
        md_ingest_service.batch_retrieve_and_process_metadata(batch_size: 3, db: db)
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

  def load_previously_saved_results
    if File.exist?(@results_path)
      LogUtilsHelper.double_log("Loading previously saved results from #{@results_path}", :info, tag: 'load_previously_saved_results')
      begin
        content = File.read(@results_path, encoding: 'utf-8')
        @results = JSON.parse(content).deep_symbolize_keys
        LogUtilsHelper.double_log("Successfully loaded results. Current counts: #{@results['counts']}", :info, tag: 'load_previously_saved_results')
      rescue => e
        LogUtilsHelper.double_log("Failed to load results from #{@results_path}: #{e.message}", :error, tag: 'load_previously_saved_results')
      end
    else
      LogUtilsHelper.double_log("No previous results found at #{@results_path}. Starting fresh.", :info, tag: 'load_previously_saved_results')
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
      # WIP: Temporarily limit the number of records retrieved for testing
      id_retrieval_service.retrieve_ids_within_date_range(output_path: record_id_path, db: db, retmax: 5)
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

  def load_results
    path = File.join(@output_dir, ATTACH_FILES_OUTPUT_DIR, 'attachment_results.jsonl')
    unless File.exist?(path)
      LogUtilsHelper.double_log("Results file not found at #{path}", :error, tag: 'load_and_format_results')
      raise "Results file not found at #{path}"
    end

    begin
      raw_results_array = JsonFileUtils.read_jsonl(path)
      format_results_for_reporting(raw_results_array)
      LogUtilsHelper.double_log("Successfully loaded and formatted results from #{path}. Current counts: #{@results[:counts]}", :info, tag: 'load_and_format_results')
    rescue => e
      LogUtilsHelper.double_log("Failed to load or parse results from #{path}: #{e.message}", :error, tag: 'load_and_format_results')
      raise "Failed to load or parse results from #{path}: #{e.message}"
    end
  end

  def format_results_for_reporting(raw_results_array)
    raw_results_array.each do |entry|
      category = entry['category']&.to_sym
      work_data = WorkUtilsHelper.fetch_work_data_by_id(entry['work_id']) if entry['work_id'].present?
      next unless [:skipped, :successfully_attached, :successfully_ingested, :failed].include?(category)

      entry.merge!(entry.delete('ids'))
      entry['cdr_url'] = WorkUtilsHelper.generate_cdr_url_for_work_id(entry['work_id']) if entry['work_id'].present?
      entry['pdf_attached'] = entry.delete('message')

      # formatted[category] << entry.except('category')
      @results[category] << entry
      @results[:counts][category] += 1
    end
  end

  def finalize_report_and_notify(attachment_results)
    if @tracker['progress']['send_summary_email']['completed']
      LogUtilsHelper.double_log('Skipping email notification as it has already been sent.', :info, tag: 'send_summary_email')
      return
    end
    # Generate report, log, send email
    LogUtilsHelper.double_log('Finalizing report and sending notification email...', :info, tag: 'send_summary_email')
    begin
      report = Tasks::PubmedIngest::SharedUtilities::PubmedReportingService.generate_report(attachment_results)
      report[:headers][:total_unique_records] = @results[:counts][:successfully_ingested] + @results[:counts][:successfully_attached] + @results[:counts][:skipped]
      PubmedReportMailer.pubmed_report_email(report).deliver_now
      @tracker['progress']['send_summary_email']['completed'] = true
      @tracker.save
      LogUtilsHelper.double_log('Email notification sent successfully.', :info, tag: 'send_summary_email')
    rescue StandardError => e
      LogUtilsHelper.double_log("Failed to send email notification: #{e.message}", :error, tag: 'send_summary_email')
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    end
  end

  def self.build_pubmed_ingest_config_and_tracker(args:)
    depositor        = args[:depositor_onyen].presence || 'admin'
    resume_flag      = ActiveModel::Type::Boolean.new.cast(args[:resume])
    raw_output_dir   = args[:output_dir]
    script_start     = Time.now
    output_dir       = nil
    config           = {}

    if raw_output_dir.blank?
      puts '❌ You cannot resume or start an ingest without specifying an output directory.'
      exit(1)
    end

    if resume_flag
      output_dir = Pathname.new(raw_output_dir)
      tracker_path = output_dir.join('ingest_tracker.json')
      unless tracker_path.exist?
        puts "❌ Tracker file not found: #{tracker_path}"
        exit(1)
      end

      config = {
        'output_dir'   => output_dir.to_s,
        'restart_time' => script_start
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

      output_dir    = resolve_output_dir(raw_output_dir, script_start)
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
      tracker = Tasks::PubmedIngest::SharedUtilities::IngestTracker.build(
        config: config,
        resume: resume_flag
      )
    end

    [config, tracker]
  end

  def self.resolve_output_dir(raw_output_dir, script_start_time)
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
    if raw_full_text_dir.present?
      base = Pathname.new(raw_full_text_dir)
      base.absolute? ? base : Rails.root.join(base)
    else
      default_dir = output_dir.join("full_text_pdfs_#{script_start_time.strftime('%Y-%m-%d_%H-%M-%S')}")
      LogUtilsHelper.double_log("No full-text directory specified. Using default: #{default_dir}", :info, tag: 'PubMed Ingest')
      default_dir
    end
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
