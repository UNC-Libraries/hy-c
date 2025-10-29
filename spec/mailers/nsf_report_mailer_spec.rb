# frozen_string_literal: true
require 'rails_helper'

RSpec.describe NSFReportMailer, type: :mailer do
  describe '#nsf_report_email' do
    let(:results) do
      {
        successfully_ingested_metadata_only: [
          { filename: 'paper1.pdf', doi: '10.1234/test1', message: 'Ingest OK' }
        ],
        failed: [
          { filename: 'paper2.pdf', doi: '10.5678/test2', message: 'Ingest failed' }
        ]
      }
    end

    let(:zip_path) { '/fake/path/nsf_results.zip' }

    before do
      allow(LogUtilsHelper).to receive(:double_log)
    end

    it 'delegates to ingest_report_email with correct template' do
      report = { subject: 'NSF Test Report' }

      expect_any_instance_of(BaseIngestReportMailer)
        .to receive(:ingest_report_email)
        .with(
          report: report,
          zip_path: zip_path,
          template_name: 'nsf_report_email'
        )

      described_class.new.nsf_report_email(report: report, zip_path: zip_path)
    end

    describe 'the generated email' do
      before do
        # reset mailer mocks to use the real implementation
        RSpec::Mocks.space.proxy_for(NSFReportMailer).reset
      end

      let(:report_hash) do
        {
          headers: {
            depositor: 'nsf_user',
            total_files: 12
          },
          subject: 'NSF Ingest Report',
          records: results,
          categories: {
            successfully_ingested_metadata_only: 'Successfully Ingested (Metadata Only)',
            failed: 'Failed'
          },
          truncated_categories: [],
          max_display_rows: 50,
          formatted_time: Time.now.strftime('%Y-%m-%d %H:%M:%S')
        }
      end

      let(:mail) { described_class.nsf_report_email(report: report_hash, zip_path: zip_path) }

      it 'renders depositor and total file count in the body' do
        expect(mail.body.encoded).to include('<strong>Depositor: </strong>nsf_user')
        expect(mail.body.encoded).to match(/<strong>Total Files: <\/strong>\s*12/)
      end

      it 'includes rows for each record' do
        results.each_value do |records|
          records.each do |r|
            expect(mail.body.encoded).to include(r[:filename])
            expect(mail.body.encoded).to include(r[:doi])
            expect(mail.body.encoded).to include(r[:message])
          end
        end
      end

      it 'sets a meaningful subject line' do
        expect(mail.subject).to eq('NSF Ingest Report')
      end
    end
  end
end
