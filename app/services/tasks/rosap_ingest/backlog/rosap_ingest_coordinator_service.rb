# frozen_string_literal: true
class Tasks::RosapIngest::Backlog::RosapIngestCoordinatorService
  LOAD_METADATA_OUTPUT_DIR  = '01_load_and_ingest_metadata'
  ATTACH_FILES_OUTPUT_DIR   = '02_attach_files_to_works'
  RESULT_CSV_OUTPUT_DIR     = '03_generate_result_csvs'
  MAX_ROWS = 100

  def initialize(config)
      # Initialize ingest tracker
    @config = config
    @tracker = Tasks::RosapIngest::Backlog::Utilities::RosapIngestTracker.build(
        config: config,
        resume: config['resume'])
    @md_ingest_results_path = File.join(@config['output_dir'], LOAD_METADATA_OUTPUT_DIR, 'metadata_ingest_results.jsonl')
    @file_attachment_results_path = File.join(@config['output_dir'], ATTACH_FILES_OUTPUT_DIR, 'attachment_results.jsonl')
    @generated_results_csv_dir = File.join(@config['output_dir'], RESULT_CSV_OUTPUT_DIR)
      # Create output directories if they don't exist
    generate_output_subdirectories
  end

  def run
    NotificationUtilsHelper.suppress_emails do
      load_and_ingest_metadata
      attach_files
    end
    format_results_and_notify

    LogUtilsHelper.double_log('ROSA-P ingest workflow completed successfully.', :info, tag: 'RosapIngestCoordinator')
    rescue => e
      LogUtilsHelper.double_log("ROSA-P ingest workflow failed: #{e.message}", :error, tag: 'RosapIngestCoordinator')
      raise e
  end

  def load_and_ingest_metadata
    if @tracker['progress']['metadata_ingest']['completed']
      LogUtilsHelper.double_log('Metadata ingest already completed according to tracker. Skipping this step.', :info, tag: 'RosapIngestCoordinatorService')
      return
    end
    LogUtilsHelper.double_log('Starting metadata ingest step.', :info, tag: 'RosapIngestCoordinatorService')
    md_ingest_service = Tasks::RosapIngest::Backlog::Utilities::MetadataIngestService.new(
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
      LogUtilsHelper.double_log('File attachment already completed according to tracker. Skipping this step.', :info, tag: 'RosapIngestCoordinatorService')
      return
    end
    LogUtilsHelper.double_log('Starting file attachment step.', :info, tag: 'RosapIngestCoordinatorService')
    file_attachment_service = Tasks::RosapIngest::Backlog::Utilities::FileAttachmentService.new(
        config: @config,
        tracker: @tracker,
        log_file_path: @file_attachment_results_path,
        metadata_ingest_result_path: @md_ingest_results_path
    )
    file_attachment_service.run
    @tracker['progress']['attach_files_to_works']['completed'] = true
    @tracker.save
  end

  def format_results_and_notify
    if @tracker['progress']['send_summary_email']['completed']
      LogUtilsHelper.double_log('Result formatting and notification already completed according to tracker. Skipping this step.', :info, tag: 'RosapIngestCoordinatorService')
      return
    end
    LogUtilsHelper.double_log('Starting result formatting and notification step.', :info, tag: 'RosapIngestCoordinatorService')
    notification_service = Tasks::RosapIngest::Backlog::Utilities::NotificationService.new(
      config: @config,
      tracker: @tracker,
      output_dir: @generated_results_csv_dir,
      file_attachment_results_path: @file_attachment_results_path,
      max_display_rows: MAX_ROWS
    )
    notification_service.run
    @tracker['progress']['send_summary_email']['completed'] = true
    @tracker.save
  end

  def generate_output_subdirectories
    [LOAD_METADATA_OUTPUT_DIR, ATTACH_FILES_OUTPUT_DIR, RESULT_CSV_OUTPUT_DIR].each do |dir|
      full_path = File.join(@config['output_dir'], dir)
      FileUtils.mkdir_p(full_path) unless Dir.exist?(full_path)
    end
  end
end
