# frozen_string_literal: true
# Preview all emails at http://localhost:3000/rails/mailers/pubmed_report_mailer
class PubmedReportMailerPreview < ActionMailer::Preview
    # ID, Title, URL, New Work Or File Added to Existing
    # Other Helpful Info
  def pubmed_report_email
      # Create Fixture
    pubmed_ingest_output_fixture = File.read(File.join(Rails.root, '/spec/fixtures/files/pubmed_ingest_test_fixture.json'))
      # Generate Report
    report = Tasks::PubmedIngest::SharedUtilities::PubmedReportingService.generate_report(JSON.parse(pubmed_ingest_output_fixture, symbolize_names: true))
    report = report.symbolize_keys
    report[:headers][:total_unique_records] = 23
    report[:headers][:start_date] = '2024-01-01'
    report[:headers][:end_date] = '2024-01-31'
      # Send Email
    PubmedReportMailer.pubmed_report_email(report)
  end
end
