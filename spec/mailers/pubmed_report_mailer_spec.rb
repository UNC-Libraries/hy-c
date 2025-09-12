# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PubmedReportMailer, type: :mailer do
  describe 'pubmed_report_email for recurring pubmed ingests' do
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

    before do
      coordinator.instance_variable_set(:@results, results)
      allow(PubmedReportMailer).to receive(:pubmed_report_email).and_call_original
      coordinator.send(:send_report_and_notify, results)
    end

    let(:report) do
      expect(PubmedReportMailer).to have_received(:pubmed_report_email) do |arg|
        return arg
      end
    end

    let(:mail) { described_class.pubmed_report_email(report) }

    it 'sets total_unique_records and date range from tracker' do
      expect(report[:headers][:total_unique_records]).to eq(
        tracker['progress']['adjust_id_lists']['pubmed']['adjusted_size'] +
        tracker['progress']['adjust_id_lists']['pmc']['adjusted_size']
      )
      expect(report[:headers][:depositor]).to eq('recurring_user')
      expect(report[:headers][:start_date]).to eq('2025-08-01')
      expect(report[:headers][:end_date]).to eq('2025-08-13')
    end

    it 'includes key header info in the email body' do
      expect(mail.body.encoded).to include('<strong>Depositor: </strong>recurring_user')
      expect(mail.body.encoded).to match(/<strong>Total Unique Records: <\/strong>\s*#{report[:headers][:total_unique_records]}/)
      expect(mail.body.encoded).to match(/<strong>Date Range: <\/strong>\s*2025-08-01 to 2025-08-13/)
    end

    it 'lists a sample record from each category' do
      # %i[successfully_ingested_and_attached successfully_ingested_metadata_only successfully_ingested failed].each do |category|
      %i[successfully_ingested_and_attached successfully_ingested_metadata_only
          successfully_attached skipped_file_attachment skipped
          failed skipped_non_unc_affiliation].each do |category|
        sample = results[category].first
        expect(mail.body.encoded).to include(sample[:file_name].to_s)
        expect(mail.body.encoded).to include(sample[:cdr_url].to_s)
        expect(mail.body.encoded).to include(sample[:message].to_s)
        expect(mail.body.encoded).to include(sample[:pmid].to_s || 'NONE')
        expect(mail.body.encoded).to include(sample[:pmcid].to_s || 'NONE')
        expect(mail.body.encoded).to include(sample[:doi].to_s || 'NONE')
      end
    end
  end
end
