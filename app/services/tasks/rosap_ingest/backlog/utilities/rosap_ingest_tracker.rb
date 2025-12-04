# frozen_string_literal: true
class Tasks::RosapIngest::Backlog::Utilities::RosapIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress'].merge!(
      'metadata_ingest' => {
        'completed' => false
      }
    )
  end
end
