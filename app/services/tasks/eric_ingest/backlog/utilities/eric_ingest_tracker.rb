# frozen_string_literal: true
class Tasks::EricIngest::Backlog::Utilities::EricIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress'].merge!(
      'metadata_ingest' => {
        'completed' => false
      },
      'attach_files_to_works' => { 'completed' => false },
      'send_summary_email' => { 'completed' => false }
    )
  end
end
