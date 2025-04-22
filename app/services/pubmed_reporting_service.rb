# frozen_string_literal: true
module Tasks
    class PubmedReportingService
        def  self.generate_report(ingest_output)
           { 
                subject: "Pubmed Ingest Report for #{ingest_output['time']}"
                headers: {
                    reporting_message: "Reporting publications from Pubmed Ingest on #{ingest_output['time']}",
                    total_unique_files: "#{ingest_output['counts']['total_unique_files']}",
                    depositor: "#{ingest_output['depositor']}",
                    target_directory: "#{ingest_output['directory_or_csv']}"
                    successfully_attached: "#{ingest_output['counts']['successfully_attached']}"
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