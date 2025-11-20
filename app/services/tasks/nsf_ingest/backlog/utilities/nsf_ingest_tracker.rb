# frozen_string_literal: true
class Tasks::NSFIngest::Backlog::Utilities::NsfIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress']['metadata_ingest'] = {
        'completed' => false
      }
    @data['file_info_csv_path'] = config['file_info_csv_path']
  end
end
