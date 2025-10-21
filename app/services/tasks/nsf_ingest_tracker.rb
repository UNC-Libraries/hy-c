# frozen_string_literal: true
class Tasks::NsfIngestTracker < Tasks::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress'].merge!(
      'metadata_ingest' => {
        'completed' => false
      },
      'attach_files_to_works' => { 'completed' => false },
      'send_summary_email' => { 'completed' => false }
    )
    @data['file_info_csv_path'] = config['file_info_csv_path']
  end
end
