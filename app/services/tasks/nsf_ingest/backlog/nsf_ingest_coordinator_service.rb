# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService
  LOAD_METADATA_OUTPUT_DIR  = '01_load_and_ingest_metadata'
  ATTACH_FILES_OUTPUT_DIR   = '02_attach_files_to_works'
  RESULT_CSV_OUTPUT_DIR     = '03_generate_result_csvs'
  def initialize(config)
    # Initialize ingest tracker
    @config = config
    @tracker = Tasks::NsfIngestTracker.build(
        config: config,
        resume: config['resume'])
    # Create output directories if they don't exist
    generate_output_subdirectories
  end

  def run
    # Step 1: Ingest metadata from CSV
    unless @tracker['progress']['metadata_ingest']['completed']
      md_ingest_service = Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService.new(
        config: @config,
        tracker: @tracker,
        md_ingest_results_path: File.join(@config['output_dir'], LOAD_METADATA_OUTPUT_DIR, 'metadata_ingest_results.jsonl')
      )
      md_ingest_service.process_backlog
      @tracker.save
    end
  end

  def generate_output_subdirectories
    [LOAD_METADATA_OUTPUT_DIR, ATTACH_FILES_OUTPUT_DIR, RESULT_CSV_OUTPUT_DIR].each do |dir|
      full_path = File.join(@config['output_dir'], dir)
      FileUtils.mkdir_p(full_path) unless Dir.exist?(full_path)
    end
  end
end
