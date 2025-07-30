# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService
    def initialize(record_ids:, result_tracker:)
        @record_ids = record_ids
        @result_tracker = result_tracker
    end

    def batch_retrieve_and_process_metadata(batch_size: 100)
end
