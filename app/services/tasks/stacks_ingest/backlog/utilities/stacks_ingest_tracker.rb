# frozen_string_literal: true
class Tasks::StacksIngest::Backlog::Utilities::StacksIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress'].merge!(
      'metadata_ingest' => {
        'completed' => false
      }
    )
  end
end
