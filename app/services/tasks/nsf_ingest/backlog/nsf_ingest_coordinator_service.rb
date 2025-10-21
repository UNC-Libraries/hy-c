# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService
  LOAD_METADATA_OUTPUT_DIR  = '01_load_and_ingest_metadata'
  ATTACH_FILES_OUTPUT_DIR   = '02_attach_files_to_works'
  RESULT_CSV_OUTPUT_DIR     = '03_generate_result_csvs'
  MAX_ROWS = 100

  def initialize(config)
    # Initialize ingest tracker
    @config = config
    @tracker = Tasks::NsfIngestTracker.build(
        config: config,
        resume: config['resume'])
    @md_ingest_results_path = File.join(@config['output_dir'], LOAD_METADATA_OUTPUT_DIR, 'metadata_ingest_results.jsonl')
    @file_attachment_results_path = File.join(@config['output_dir'], ATTACH_FILES_OUTPUT_DIR, 'attachment_results.jsonl')
    @final_ingest_results_path = File.join(@config['output_dir'], 'final_ingest_results.json')
    # Create output directories if they don't exist
    generate_output_subdirectories
  end

  def run
    NotificationUtilsHelper.suppress_emails do
      load_and_ingest_metadata
      attach_files
    end

    LogUtilsHelper.double_log('NSF ingest workflow completed successfully.', :info, tag: 'NSFIngestCoordinator')
    rescue => e
      LogUtilsHelper.double_log("NSF ingest workflow failed: #{e.message}", :error, tag: 'NSFIngestCoordinator')
      raise e
  end

  def load_and_ingest_metadata
    if @tracker['progress']['metadata_ingest']['completed']
      LogUtilsHelper.double_log('[NsfIngestCoordinatorService] Metadata ingest already completed according to tracker. Skipping this step.', :info, tag: 'NsfIngestCoordinatorService')
      return
    end
    md_ingest_service = Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService.new(
      config: @config,
      tracker: @tracker,
      md_ingest_results_path: @md_ingest_results_path
    )
    md_ingest_service.process_backlog
    @tracker['progress']['metadata_ingest']['completed'] = true
    @tracker.save
  end

  def attach_files
    if @tracker['progress']['attach_files_to_works']['completed']
      LogUtilsHelper.double_log('[NsfIngestCoordinatorService] File attachment already completed according to tracker. Skipping this step.', :info, tag: 'NsfIngestCoordinatorService')
      return
    end
    file_attachment_service = Tasks::NsfIngest::Backlog::Utilities::FileAttachmentService.new(
      config: @config,
      tracker: @tracker,
      log_file_path: @file_attachment_results_path,
      file_info_path: @config['file_info_csv_path'],
      metadata_ingest_result_path: @md_ingest_results_path
    )
    file_attachment_service.run
    # WIP: Disabled for testing
    # @tracker['progress']['attach_files_to_works']['completed'] = true
    # @tracker.save
  end

  def format_results_and_notify
    notification_service = Tasks::NSFIngest::Backlog::Utilities::IngestNotificationService.new(
      config: @config,
      tracker: @tracker,
      log_file_path: @final_ingest_results_path,
      file_attachment_results_path: @file_attachment_results_path,
      max_display_rows: MAX_ROWS
    )
    notification_service.run
    JsonFileUtilsHelper.write_json(@results, @final_ingest_results_path, pretty: true)
  end

  def generate_output_subdirectories
    [LOAD_METADATA_OUTPUT_DIR, ATTACH_FILES_OUTPUT_DIR, RESULT_CSV_OUTPUT_DIR].each do |dir|
      full_path = File.join(@config['output_dir'], dir)
      FileUtils.mkdir_p(full_path) unless Dir.exist?(full_path)
    end
  end
end
