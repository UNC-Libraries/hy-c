# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PubmedReportMailer, type: :mailer do
  describe 'truncated_pubmed_report_email for recurring pubmed ingests' do
    let(:fixture_path) do
      Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture.json')
    end

    let(:results) { JSON.parse(File.read(fixture_path), symbolize_names: true) }

    let(:tracker) do
      progress_hash = {
        'send_summary_email' => { 'completed' => false },
        'adjust_id_lists' => {
          'pubmed' => { 'adjusted_size' => 3 },
          'pmc'    => { 'adjusted_size' => 2 }
        }
      }
      instance_double(
        'IngestTracker',
        'progress' => progress_hash,
        'depositor_onyen' => 'recurring_user',
        'date_range' => { 'start' => '2025-08-01', 'end' => '2025-08-13' },
        :save => true
      ).tap do |dbl|
        allow(dbl).to receive(:[]).with('depositor_onyen').and_return('recurring_user')
        allow(dbl).to receive(:[]).with('date_range').and_return({ 'start' => '2025-08-01', 'end' => '2025-08-13' })
        allow(dbl).to receive(:[]).with('progress').and_return(progress_hash)
      end
    end

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

    let(:coordinator) do
      Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService.new(config, tracker)
    end

    let(:csv_paths) do
      [
        '/fake/path/successfully_ingested_and_attached.csv',
        '/fake/path/failed.csv'
      ]
    end

    let(:zip_path) { '/fake/path/results.zip' }

    let(:captured_report) { @captured_report }
    let(:captured_zip_path) { @captured_zip_path }

    before do
      # Allow LogUtilsHelper calls in the mailer
      allow(LogUtilsHelper).to receive(:double_log)

      coordinator.instance_variable_set(:@results, results)

      # Stub CSV generation methods
      allow(coordinator).to receive(:generate_result_csvs).and_return(csv_paths)
      allow(coordinator).to receive(:compress_result_csvs).and_return(zip_path)

      # Stub File operations for the mailer
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(zip_path).and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(zip_path).and_return('fake zip content')

      # Capture the arguments passed to the mailer
      allow(PubmedReportMailer).to receive(:truncated_pubmed_report_email) do |report, zip|
        @captured_report = report
        @captured_zip_path = zip
        double('mailer', deliver_now: true)
      end

      coordinator.send(:send_report_and_notify, results)
    end

    it 'sets total_unique_records and date range from tracker' do
      expect(captured_report[:headers][:total_unique_records]).to eq(
        tracker['progress']['adjust_id_lists']['pubmed']['adjusted_size'] +
        tracker['progress']['adjust_id_lists']['pmc']['adjusted_size']
      )
      expect(captured_report[:headers][:depositor]).to eq('recurring_user')
      expect(captured_report[:headers][:start_date]).to eq('2025-08-01')
      expect(captured_report[:headers][:end_date]).to eq('2025-08-13')
    end

    it 'calls the mailer with the report and zip path' do
      expect(PubmedReportMailer).to have_received(:truncated_pubmed_report_email).with(
        hash_including(headers: hash_including(total_unique_records: 5)),
        zip_path
      )
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

      let(:mail) { described_class.truncated_pubmed_report_email(report_hash, zip_path) }

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

      it 'attaches the zip file' do
        expect(mail.attachments.size).to eq(1)
        expect(mail.attachments.first.filename).to eq('results.zip')
      end
    end
  end
end
