# Preview all emails at http://localhost:3000/rails/mailers/dimensions_report_mailer
class DimensionsReportMailerPreview < ActionMailer::Preview
    def report_email
        # WIP: Ensuring template works after an ingest with a test fixture, removing later
        dimensions_ingest_test_fixture =  File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
        test_publications = JSON.parse(dimensions_ingest_test_fixture)['publications']
        config = {
            'admin_set' => 'default',
            'depositor_onyen' => 'admin'
          }
        dimensions_ingest_service = Tasks::DimensionsIngestService.new(config)
        ingested_publications = dimensions_ingest_service.ingest_publications(test_publications)
        dimensions_reporting_service = Tasks::DimensionsReportingService.new(ingested_publications)
        report = dimensions_reporting_service.generate_report
        DimensionsReportMailer.report_email(report)
    end
end
