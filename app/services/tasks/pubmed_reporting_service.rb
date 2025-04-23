# frozen_string_literal: true
module Tasks
  class PubmedReportingService
    def  self.generate_report(ingest_output)
      formatted_time = Time.parse(ingest_output['time']).strftime('%B %d, %Y at %I:%M %p %Z')
      {
           subject: "Pubmed Ingest Report for #{formatted_time}",
           formatted_time: formatted_time,
           file_retrieval_directory: "#{ingest_output['file_retrieval_directory']}",
           headers: {
               depositor: "#{ingest_output['depositor']}",
               total_unique_files: "#{ingest_output['counts']['total_unique_files']}",
           },
           records: {
               successfully_attached: ingest_output['successfully_attached'],
               successfully_ingested: ingest_output['successfully_ingested'],
               skipped: ingest_output['skipped'],
               failed: ingest_output['failed']
           },
       }
    end
  end
end
