# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PubmedReportMailer, type: :mailer do
  describe 'pubmed_report_email for recurring pubmed ingests' do
    let(:fixture_path) do
      Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture.json')
    end

    let(:results) { JSON.parse(File.read(fixture_path), symbolize_names: true) }

    let(:config) do
      {
        'time' => Time.now,
        'start_date' => Date.parse('2025-08-01'),
        'end_date' => Date.parse('2025-08-13'),
        'admin_set_title' => 'Test Admin Set',
        'depositor_onyen' => 'recurring_user',
        'output_dir' => '/path/to/output',
        'full_text_dir' => '/path/to/full_text'
      }
    end

    let(:zip_path) { '/fake/path/results.zip' }

    before do
      # Allow LogUtilsHelper calls in the mailer
      allow(LogUtilsHelper).to receive(:double_log)
    end

    it 'delegates to ingest_report_email with correct template' do
      report = { subject: 'PubMed Test' }
      zip_path = '/fake/path/results.zip'

      expect_any_instance_of(BaseIngestReportMailer)
        .to receive(:ingest_report_email)
        .with(
          report: report,
          zip_path: zip_path,
          template_name: 'pubmed_report_email'
        )

      described_class.new.pubmed_report_email(report: report, zip_path: zip_path)
    end

    describe 'the generated email' do
      # Don't stub the mailer in this context - we want the real thing
      before do
        RSpec::Mocks.space.proxy_for(PubmedReportMailer).reset
      end

      let(:report_hash) do
        {
          headers: {
            total_unique_records: 5,
            depositor: 'recurring_user',
            start_date: '2025-08-01',
            end_date: '2025-08-13'
          },
          subject: 'PubMed Ingest Report',
          records: results,
          categories: {
            successfully_ingested_and_attached: 'Successfully Ingested and Attached',
            successfully_ingested_metadata_only: 'Successfully Ingested (Metadata Only)',
            successfully_attached: 'Successfully Attached To Existing Work',
            skipped_file_attachment: 'Skipped File Attachment To Existing Work',
            skipped: 'Skipped',
            failed: 'Failed',
            skipped_non_unc_affiliation: 'Skipped (No UNC Affiliation)'
          },
          truncated_categories: [],
          max_display_rows: 100
        }
      end

      let(:mail) { described_class.pubmed_report_email(report: report_hash, zip_path: zip_path) }

      it 'includes key header info in the email body' do
        expect(mail.body.encoded).to include('<strong>Depositor: </strong>recurring_user')
        expect(mail.body.encoded).to match(/<strong>Total Unique Records: <\/strong>\s*5/)
        expect(mail.body.encoded).to match(/<strong>Date Range: <\/strong>\s*2025-08-01 to 2025-08-13/)
      end

      it 'lists a sample record from each category' do
        %i[successfully_ingested_and_attached successfully_ingested_metadata_only
            successfully_attached skipped_file_attachment skipped
            failed skipped_non_unc_affiliation].each do |category|
          next if results[category].nil? || results[category].empty?

          sample = results[category].first
          expect(mail.body.encoded).to include(sample[:file_name].to_s) if sample[:file_name]
          expect(mail.body.encoded).to include(sample[:cdr_url].to_s) if sample[:cdr_url]
          expect(mail.body.encoded).to include(sample[:message].to_s) if sample[:message]
          expect(mail.body.encoded).to include(sample[:pmid].to_s) if sample[:pmid]
          expect(mail.body.encoded).to include(sample[:pmcid].to_s) if sample[:pmcid]
          expect(mail.body.encoded).to include(sample[:doi].to_s) if sample[:doi]
        end
      end
    end
  end
end
