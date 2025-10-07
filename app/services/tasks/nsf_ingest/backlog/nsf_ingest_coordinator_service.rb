# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService
  LOAD_METADATA_OUTPUT_DIR  = '01_load_and_ingest_metadata'
  ATTACH_FILES_OUTPUT_DIR   = '02_attach_files_to_works'
  RESULT_CSV_OUTPUT_DIR     = '03_generate_result_csvs'
end