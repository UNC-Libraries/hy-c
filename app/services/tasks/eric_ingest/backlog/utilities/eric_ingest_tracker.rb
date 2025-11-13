# frozen_string_literal: true
class Tasks::EricIngest::Backlog::Utilities::EricIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress'].merge!(
      'metadata_ingest' => {
        'completed' => false
      }
    )
  end
end
