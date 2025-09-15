# frozen_string_literal: true
module Tasks
  module PubmedIngest
    module SharedUtilities
      class PubmedReportingService
        def self.generate_report(ingest_output)
          formatted_time = Time.parse(ingest_output[:time].to_s).strftime('%B %d, %Y at %I:%M %p %Z')
          {
            subject: "Pubmed Ingest Report for #{formatted_time}",
            formatted_time: formatted_time,
            file_retrieval_directory: ingest_output[:file_retrieval_directory],
            headers: {
              depositor: ingest_output[:depositor]
            },
            records: {
              successfully_ingested_and_attached: ingest_output[:successfully_ingested_and_attached].map(&:symbolize_keys),
              successfully_ingested_metadata_only: ingest_output[:successfully_ingested_metadata_only].map(&:symbolize_keys),
              successfully_attached: ingest_output[:successfully_attached].map(&:symbolize_keys),
              skipped_file_attachment: ingest_output[:skipped_file_attachment].map(&:symbolize_keys),
              skipped: ingest_output[:skipped].map(&:symbolize_keys),
              failed: ingest_output[:failed].map(&:symbolize_keys),
              skipped_non_unc_affiliation: ingest_output[:skipped_non_unc_affiliation].map(&:symbolize_keys)
            }
          }
        end
      end
    end
end
end
