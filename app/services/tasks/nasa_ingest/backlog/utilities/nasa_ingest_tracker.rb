# frozen_string_literal: true
class Tasks::NASAIngest::Backlog::Utilities::NASAIngestTracker < Tasks::IngestHelperUtils::BaseIngestTracker
  def initialize_new!(config)
    super
    @data['progress']['metadata_ingest'] = {
        'completed' => false
    }
    @data['data_dir'] = config['data_dir']
  end
end
