# frozen_string_literal: true
class Tasks::PubmedIngest::SharedUtilities::PubmedIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress'].merge!(
      'retrieve_ids_within_date_range' => {
        'pubmed' => { 'cursor' => 0, 'completed' => false },
        'pmc' => { 'cursor' => 0, 'completed' => false }
      },
      'stream_and_write_alternate_ids' => {
        'pubmed' => { 'cursor' => 0, 'completed' => false },
        'pmc' => { 'cursor' => 0, 'completed' => false }
      },
      'adjust_id_lists' => {
        'completed' => false,
        'pubmed' => { 'original_size' => 0, 'adjusted_size' => 0 },
        'pmc' => { 'original_size' => 0, 'adjusted_size' => 0 }
      },
      'metadata_ingest' => {
        'pubmed' => { 'completed' => false },
        'pmc' => { 'completed' => false }
      }
    )
  end
end
