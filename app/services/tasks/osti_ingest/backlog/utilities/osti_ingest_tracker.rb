# frozen_string_literal: true
class Tasks::OstiIngest::Backlog::Utilities::OstiIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress']['metadata_ingest'] = {
        'completed' => false
    }
    @data['input_csv_path'] = config['input_csv_path']
  end
end
