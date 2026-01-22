# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NoaaIngest::Backlog::Utilities::FileAttachmentService do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:file_set) { FactoryBot.build(:file_set) }
  let(:config) do
    {
      'start_time' => DateTime.new(2024, 1, 1),
      'restart_time' => nil,
      'resume' => false,
      'admin_set_title' => admin_set.title,
      'depositor_onyen' => depositor.uid,
      'output_dir' => '/tmp/stacks_output',
      'full_text_dir' => '/tmp/stacks_full_text',
      'input_csv_path' => '/tmp/stacks_data.csv'
    }
  end
  let(:tracker) { Tasks::NoaaIngest::Backlog::Utilities::NoaaIngestTracker.new(config) }
  let(:log_file_path) { '/tmp/stacks_attachment_log.jsonl' }
  let(:metadata_ingest_result_path) { '/tmp/stacks_metadata_ingest_results.jsonl' }

  let(:csv_data) do
    <<~CSV
      noaa_id,stacks_url,doi,pmid,pmcid,cdr_url,has_fileset,main_file,supplemental_files,supplemental_labels
      79129,https://stacks.noaa.gov/view/noaa/79129,http://dx.doi.org/10.1353/cpr.2018.0010,29606697,PMC6542568,,,noaa_79129_DS1.pdf,noaa_79129_DS2.gif|noaa_79129_DS3.jpeg|noaa_79129_DS4.gif,label1|label2|label3
      140512,https://stacks.noaa.gov/view/noaa/140512,,,,,,noaa_140512_DS1.pdf,"",""
      134910,https://stacks.noaa.gov/view/noaa/134910,,,,,,noaa_134910_DS1.pdf,index.html,index.html
      151720,https://stacks.noaa.gov/view/noaa/151720,,37714542,PMC10940227,,,,"",""
    CSV
  end

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      log_file_path: log_file_path,
      metadata_ingest_result_path: metadata_ingest_result_path
    )
  end

  before do
    File.write(config['input_csv_path'], csv_data)
    allow(AdminSet).to receive(:where).with(title: admin_set.title).and_return([admin_set])
    allow(service).to receive(:load_seen_attachment_ids).and_return(Set.new)
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  after do
    File.delete(config['input_csv_path']) if File.exist?(config['input_csv_path'])
    File.delete(log_file_path) if File.exist?(log_file_path)
  end

  describe '#initialize' do
    it 'loads CSV rows' do
      csv_rows = service.instance_variable_get(:@csv_rows)
      expect(csv_rows.size).to eq(4)
      expect(csv_rows.first['noaa_id']).to eq('79129')
    end

    it 'sets full_text_path from config' do
      expect(service.instance_variable_get(:@full_text_path)).to eq('/tmp/stacks_full_text')
    end

    it 'sets input_csv_path from config' do
      expect(service.instance_variable_get(:@input_csv_path)).to eq('/tmp/stacks_data.csv')
    end

    it 'initializes existing_ids set' do
      existing_ids = service.instance_variable_get(:@existing_ids)
      expect(existing_ids).to be_a(Set)
    end
  end

  describe '#process_record' do
    let(:article) { FactoryBot.create(:article) }
    let(:record) do
      {
        'ids' => {
          'work_id' => article.id,
          'noaa_id' => '79129'
        }
      }
    end

    before do
      allow(Article).to receive(:find).with(article.id).and_return(article)
      allow(User).to receive(:find_by).with(uid: depositor.uid).and_return(depositor)
      allow(File).to receive(:exist?).and_call_original
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_return(file_set)
      allow(service).to receive(:attach_file_set_to_work).and_return(file_set)
      allow(service).to receive(:log_attachment_outcome)
      allow(service).to receive(:sleep)
    end

    context 'when CSV row is not found' do
      let(:record_no_csv) do
        {
          'ids' => {
            'work_id' => article.id,
            'noaa_id' => '999999'
          }
        }
      end

      it 'logs skipped outcome with "No CSV row found" message' do
        service.process_record(record_no_csv)

        expect(service).to have_received(:log_attachment_outcome).with(
          record_no_csv,
          category: :skipped,
          message: 'No CSV row found',
          file_name: 'N/A'
        )
      end

      it 'does not attempt to attach any files' do
        service.process_record(record_no_csv)

        expect(service).not_to have_received(:attach_pdf_to_work_with_file_path!)
        expect(service).not_to have_received(:attach_file_set_to_work)
      end
    end

    context 'with main file only' do
      before do
        allow(File).to receive(:exist?)
          .with('/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf')
          .and_return(true)
      end

      it 'attaches main PDF and logs success' do
        service.process_record(record)

        expect(service).to have_received(:attach_pdf_to_work_with_file_path!).with(
          record: record,
          file_path: '/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf',
          depositor_onyen: depositor.uid
        )
        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :successfully_ingested_and_attached,
          message: 'Main PDF successfully attached',
          file_name: 'noaa_79129_DS1.pdf'
        )
      end

      it 'sleeps after attaching main file' do
        service.process_record(record)

        expect(service).to have_received(:sleep).with(0.5)
      end
    end

    context 'when main file does not exist' do
      before do
        allow(File).to receive(:exist?)
          .with('/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf')
          .and_return(false)
      end

      it 'logs failed outcome' do
        service.process_record(record)

        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'Main file not found',
          file_name: 'noaa_79129_DS1.pdf'
        )
        expect(service).not_to have_received(:attach_pdf_to_work_with_file_path!)
      end
    end

    context 'with main file and supplemental files' do
      before do
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf').and_return(true)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS2.gif').and_return(true)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS3.jpeg').and_return(true)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS4.gif').and_return(true)
      end

      it 'attaches main file and all supplemental files' do
        service.process_record(record)

        expect(service).to have_received(:attach_pdf_to_work_with_file_path!).once
        expect(service).to have_received(:attach_file_set_to_work).exactly(3).times

        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :successfully_ingested_and_attached,
          message: 'Main PDF successfully attached',
          file_name: 'noaa_79129_DS1.pdf'
        )
        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :successfully_ingested_and_attached,
          message: 'Supplemental file successfully attached',
          file_name: 'noaa_79129_DS2.gif'
        )
      end

      it 'sleeps after each file attachment' do
        service.process_record(record)

        # 1 main + 3 supplemental = 4 sleep calls
        expect(service).to have_received(:sleep).with(0.5).exactly(4).times
      end

      it 'logs info for each supplemental file' do
        service.process_record(record)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          "Attaching supplemental file noaa_79129_DS2.gif to work #{article.id}",
          :info,
          tag: 'Noaa File Attachment Service'
        )
      end
    end

    context 'when some supplemental files are missing' do
      before do
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf').and_return(true)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS2.gif').and_return(true)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS3.jpeg').and_return(false)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS4.gif').and_return(true)
      end

      it 'attaches available files and logs failures for missing ones' do
        service.process_record(record)

        expect(service).to have_received(:attach_file_set_to_work).exactly(2).times # Only DS2 and DS4
        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'Supplemental file not found',
          file_name: 'noaa_79129_DS3.jpeg'
        )
      end
    end

    context 'with no main file but has supplemental files' do
      let(:record_no_main) do
        {
          'ids' => {
            'work_id' => article.id,
            'noaa_id' => '151720'
          }
        }
      end

      it 'skips main file and processes supplemental files only' do
        service.process_record(record_no_main)

        expect(service).not_to have_received(:attach_pdf_to_work_with_file_path!)
        # Should not try to attach supplemental since they're empty in CSV
      end
    end

    context 'when attachment raises an error' do
      before do
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf').and_return(true)
        allow(service).to receive(:attach_pdf_to_work_with_file_path!)
          .and_raise(StandardError.new('Attachment failed'))
      end

      it 'catches error and logs failure' do
        service.process_record(record)

        expect(Rails.logger).to have_received(:error).with(/Error processing record 79129: Attachment failed/)
        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'Noaa File Attachment Error: Attachment failed',
          file_name: 'noaa_79129_DS1.pdf'
        )
      end

      it 'logs backtrace' do
        service.process_record(record)

        expect(Rails.logger).to have_received(:error).at_least(:twice)
      end
    end

    context 'when error occurs during supplemental file processing' do
      before do
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS1.pdf').and_return(true)
        allow(File).to receive(:exist?).with('/tmp/stacks_full_text/79129/noaa_79129_DS2.gif').and_return(true)
        allow(service).to receive(:attach_file_set_to_work)
          .and_raise(StandardError.new('Supplemental attachment failed'))
      end

      it 'logs the correct file name that caused the error' do
        service.process_record(record)

        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'Noaa File Attachment Error: Supplemental attachment failed',
          file_name: 'noaa_79129_DS2.gif'
        )
      end
    end
  end

  describe '#log_attachment_outcome' do
    let(:record) do
      {
        'ids' => {
          'noaa_id' => '79129',
          'work_id' => 'work123'
        }
      }
    end

    before do
      allow(File).to receive(:open).and_call_original
      allow(tracker).to receive(:save)
    end

    it 'logs attachment outcome and updates existing_ids' do
      service.log_attachment_outcome(
        record,
        category: :successfully_ingested_and_attached,
        message: 'Success',
        file_name: 'test.pdf'
      )

      existing_ids = service.instance_variable_get(:@existing_ids)
      expect(existing_ids).to include('79129:test.pdf')
    end

    it 'skips logging if tracking key already exists' do
      existing_ids = service.instance_variable_get(:@existing_ids)
      existing_ids << '79129:test.pdf'

      expect(File).not_to receive(:open)

      service.log_attachment_outcome(
        record,
        category: :successfully_ingested_and_attached,
        message: 'Success',
        file_name: 'test.pdf'
      )
    end

    it 'allows same NOAA ID with different filenames' do
      service.log_attachment_outcome(record, category: :success, message: 'msg', file_name: 'file1.pdf')
      service.log_attachment_outcome(record, category: :success, message: 'msg', file_name: 'file2.pdf')

      existing_ids = service.instance_variable_get(:@existing_ids)
      expect(existing_ids).to include('79129:file1.pdf')
      expect(existing_ids).to include('79129:file2.pdf')
    end

    it 'handles nil tracking key gracefully' do
      record_no_noaa = { 'ids' => { 'work_id' => 'work123' } }

      expect {
        service.log_attachment_outcome(
          record_no_noaa,
          category: :failed,
          message: 'Error',
          file_name: nil
        )
      }.not_to raise_error
    end
  end

  describe '#parse_pipe_delimited' do
    it 'parses pipe-delimited string into array' do
      result = service.send(:parse_pipe_delimited, 'file1.gif|file2.jpeg|file3.xml')
      expect(result).to eq(['file1.gif', 'file2.jpeg', 'file3.xml'])
    end

    it 'handles blank field' do
      result = service.send(:parse_pipe_delimited, '')
      expect(result).to eq([])
    end

    it 'handles nil field' do
      result = service.send(:parse_pipe_delimited, nil)
      expect(result).to eq([])
    end

    it 'handles double-quoted empty string' do
      result = service.send(:parse_pipe_delimited, '""')
      expect(result).to eq([])
    end

    it 'strips whitespace from filenames' do
      result = service.send(:parse_pipe_delimited, 'file1.gif | file2.jpeg |  file3.xml  ')
      expect(result).to eq(['file1.gif', 'file2.jpeg', 'file3.xml'])
    end

    it 'rejects blank entries' do
      result = service.send(:parse_pipe_delimited, 'file1.gif||file2.jpeg')
      expect(result).to eq(['file1.gif', 'file2.jpeg'])
    end
  end

  describe '#load_csv_rows' do
    it 'loads all CSV rows with headers' do
      csv_rows = service.send(:load_csv_rows)

      expect(csv_rows.size).to eq(4)
      expect(csv_rows.first['noaa_id']).to eq('79129')
      expect(csv_rows.first['main_file']).to eq('noaa_79129_DS1.pdf')
    end

    it 'preserves all columns' do
      csv_rows = service.send(:load_csv_rows)
      row = csv_rows.first

      expect(row).to have_key('noaa_id')
      expect(row).to have_key('stacks_url')
      expect(row).to have_key('doi')
      expect(row).to have_key('main_file')
      expect(row).to have_key('supplemental_files')
    end
  end

  describe 'integration with BaseFileAttachmentService' do
    it 'inherits from BaseFileAttachmentService' do
      expect(service).to be_a(Tasks::IngestHelperUtils::BaseFileAttachmentService)
    end

    it 'includes IngestHelper module' do
      expect(service.class.ancestors).to include(Tasks::IngestHelperUtils::IngestHelper)
    end

    it 'has access to base class methods' do
      expect(service).to respond_to(:run)
      expect(service).to respond_to(:fetch_attachment_candidates)
      expect(service).to respond_to(:has_fileset?)
      expect(service).to respond_to(:category_for_successful_attachment)
    end
  end
end
