# frozen_string_literal: true
# Preview all emails at http://localhost:3000/rails/mailers/dimensions_report_mailer
class DimensionsReportMailerPreview < ActionMailer::Preview
  TEST_START_DATE = '1970-01-01'
  TEST_END_DATE = '2021-01-01'
  FIXED_DIMENSIONS_TOTAL_COUNT = 2974
  def dimensions_report_email
    # Ensuring template works with a report generated after an ingest with a test fixture
    dimensions_ingest_test_fixture =  File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
    test_publications = JSON.parse(dimensions_ingest_test_fixture)['publications']
    config = {
        'admin_set' => 'default',
        'depositor_onyen' => ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
      }

    dimensions_ingest_service = Tasks::DimensionsIngestService.new(config)
    ingested_publications = dimensions_ingest_service.ingest_publications(test_publications)
    # Marking some successfully ingested publications as having attached PDFs, workaround to stubbing requests for them
    # Odd publications marked as pdf_attached for consistency with tests
    ingested_publications[:ingested].each_with_index do |pub, index|
      if index.odd?
        pub['pdf_attached'] = 'Yes'
      end
    end

    # Moving publications in the failing publication sample to the failed array and adding an error message
    failing_publication_sample = test_publications[0..2]
    ingested_publications[:ingested] = ingested_publications[:ingested].reject do |pub|
      failing_publication_sample.any? { |failing_pub| failing_pub['id'] == pub['id'] }
    end
    ingested_publications[:failed] = failing_publication_sample.map do |pub|
      pub.merge('error' => ['Test error', 'Test error message'])
    end

    dimensions_reporting_service = Tasks::DimensionsReportingService.new(ingested_publications, FIXED_DIMENSIONS_TOTAL_COUNT, { start_date: TEST_START_DATE, end_date: TEST_END_DATE }, FALSE)
    report = dimensions_reporting_service.generate_report
    DimensionsReportMailer.dimensions_report_email(report)
  end
end
