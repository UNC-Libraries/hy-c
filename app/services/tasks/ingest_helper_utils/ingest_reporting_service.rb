# frozen_string_literal: true
module Tasks
  module IngestHelperUtils
    class IngestReportingService
      DEFAULT_CATEGORIES = %i[
        successfully_ingested_and_attached
        successfully_ingested_metadata_only
        successfully_attached
        skipped_file_attachment
        skipped
        failed
        skipped_non_unc_affiliation
      ].freeze

      def self.generate_report(ingest_output:, source_name:, custom_categories: [])
        time = Time.parse(ingest_output[:time].to_s) rescue Time.now
        formatted_time = time.strftime('%B %d, %Y at %I:%M %p %Z')

        categories = (custom_categories.presence || DEFAULT_CATEGORIES)
        record_hash = categories.each_with_object({}) do |cat, hash|
          hash[cat] = (ingest_output[cat] || []).map(&:symbolize_keys)
        end

        {
          subject: "#{source_name.capitalize} Ingest Report for #{formatted_time}",
          formatted_time: formatted_time,
          source_name: source_name,
          file_retrieval_directory: ingest_output[:file_retrieval_directory],
          headers: {
            depositor: ingest_output[:depositor]
          },
          records: record_hash
        }
      end
    end
  end
end
