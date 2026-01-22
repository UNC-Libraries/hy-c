# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NoaaIngest::Backlog::Utilities::FileAttachmentResultAggregator do
  let(:attachment_results_path) { '/tmp/test_attachment_results.jsonl' }
  let(:output_path) { '/tmp/test_aggregated_results.jsonl' }
  let(:aggregator) { described_class.new(attachment_results_path: attachment_results_path, output_path: output_path) }

  before do
    allow(JsonFileUtilsHelper).to receive(:write_jsonl)
  end

  after do
    File.delete(attachment_results_path) if File.exist?(attachment_results_path)
    File.delete(output_path) if File.exist?(output_path)
  end

  describe '#initialize' do
    it 'sets attachment_results_path and output_path' do
      expect(aggregator.instance_variable_get(:@attachment_results_path)).to eq(attachment_results_path)
      expect(aggregator.instance_variable_get(:@output_path)).to eq(output_path)
    end
  end

  describe '#aggregate_results' do
    context 'with multiple files for the same work and category' do
      let(:input_data) do
        [
          { ids: { noaa_id: '79129', work_id: '474299495' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'noaa_79129_DS1.pdf' },
          { ids: { noaa_id: '79129', work_id: '474299495' }, category: 'successfully_ingested_and_attached', message: 'Supplemental file successfully attached', file_name: 'noaa_79129_DS2.gif' },
          { ids: { noaa_id: '79129', work_id: '474299495' }, category: 'successfully_ingested_and_attached', message: 'Supplemental file successfully attached', file_name: 'noaa_79129_DS3.jpeg' },
          { ids: { noaa_id: '79129', work_id: '474299495' }, category: 'successfully_ingested_and_attached', message: 'Supplemental file successfully attached', file_name: 'noaa_79129_DS4.gif' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'groups files with the same noaa_id, work_id, category, and message' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, path, options|
          expect(path).to eq(output_path)
          expect(options).to eq(mode: 'w')

          # Should have 2 groups: one for main PDF, one for supplemental files
          expect(results.size).to eq(2)

          main_group = results.find { |r| r[:message] == 'Main PDF successfully attached' }
          expect(main_group[:ids][:noaa_id]).to eq('79129')
          expect(main_group[:ids][:work_id]).to eq('474299495')
          expect(main_group[:category]).to eq('successfully_ingested_and_attached')
          expect(main_group[:filenames]).to eq(['noaa_79129_DS1.pdf'])

          supp_group = results.find { |r| r[:message] == 'Supplemental file successfully attached' }
          expect(supp_group[:filenames]).to contain_exactly('noaa_79129_DS2.gif', 'noaa_79129_DS3.jpeg', 'noaa_79129_DS4.gif')
        end
      end
    end

    context 'with multiple works' do
      let(:input_data) do
        [
          { ids: { noaa_id: '79129' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'file1.pdf' },
          { ids: { noaa_id: '79129' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'file2.pdf' },
          { ids: { noaa_id: '53458' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'file3.pdf' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'groups files separately by noaa_id' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
          expect(results.size).to eq(2)

          work1_group = results.find { |r| r[:ids][:noaa_id] == '79129' }
          expect(work1_group[:filenames]).to contain_exactly('file1.pdf', 'file2.pdf')

          work2_group = results.find { |r| r[:ids][:noaa_id] == '53458' }
          expect(work2_group[:filenames]).to eq(['file3.pdf'])
        end
      end
    end

    context 'with different categories for the same work' do
      let(:input_data) do
        [
          { ids: { noaa_id: '134910', work_id: 'r781wg334' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'noaa_134910_DS1.pdf' },
          { ids: { noaa_id: '134910', work_id: 'r781wg334' }, category: 'failed', message: 'Supplemental file not found', file_name: 'index.html' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'groups files separately by category' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
          expect(results.size).to eq(2)

          success_group = results.find { |r| r[:category] == 'successfully_ingested_and_attached' }
          expect(success_group[:filenames]).to eq(['noaa_134910_DS1.pdf'])

          failed_group = results.find { |r| r[:category] == 'failed' }
          expect(failed_group[:filenames]).to eq(['index.html'])
        end
      end
    end

    context 'with different messages for the same category' do
      let(:input_data) do
        [
          { ids: { noaa_id: '79129', work_id: 'work1' }, category: 'failed', message: 'File not found', file_name: 'missing1.pdf' },
          { ids: { noaa_id: '79129', work_id: 'work1' }, category: 'failed', message: 'Permission denied', file_name: 'missing2.pdf' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'groups files separately by message' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
          expect(results.size).to eq(2)

          not_found = results.find { |r| r[:message] == 'File not found' }
          expect(not_found[:filenames]).to eq(['missing1.pdf'])

          permission = results.find { |r| r[:message] == 'Permission denied' }
          expect(permission[:filenames]).to eq(['missing2.pdf'])
        end
      end
    end

    context 'with single file per group' do
      let(:input_data) do
        [
          { ids: { noaa_id: '79129', work_id: 'work1' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'file1.pdf' },
          { ids: { noaa_id: '53458', work_id: 'work2' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'file2.pdf' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'creates individual groups with single filename arrays' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
          expect(results.size).to eq(2)

          results.each do |result|
            expect(result[:filenames]).to be_an(Array)
            expect(result[:filenames].size).to eq(1)
          end
        end
      end
    end

    context 'with empty input file' do
      before do
        File.open(attachment_results_path, 'w') { |f| f.write('') }
      end

      it 'produces empty results' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl).with([], output_path, mode: 'w')
      end
    end

    context 'with nil values in ids' do
      let(:input_data) do
        [
          { ids: { noaa_id: nil, work_id: 'work1' }, category: 'failed', message: 'NOAA ID missing', file_name: 'file1.pdf' },
          { ids: { noaa_id: nil, work_id: 'work1' }, category: 'failed', message: 'NOAA ID missing', file_name: 'file2.pdf' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'groups files with nil NOAA IDs together' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
          expect(results.size).to eq(1)
          expect(results.first[:ids][:noaa_id]).to be_nil
          expect(results.first[:filenames]).to contain_exactly('file1.pdf', 'file2.pdf')
        end
      end
    end

    context 'with complex real-world data' do
      let(:input_data) do
        [
          # Work 1: Main + multiple supplemental files
          { ids: { noaa_id: '75969', work_id: 'ft848q83z' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'noaa_75969_DS1.pdf' },
          { ids: { noaa_id: '75969', work_id: 'ft848q83z' }, category: 'successfully_ingested_and_attached', message: 'Supplemental file successfully attached', file_name: 'noaa_75969_DS10.xml' },
          { ids: { noaa_id: '75969', work_id: 'ft848q83z' }, category: 'successfully_ingested_and_attached', message: 'Supplemental file successfully attached', file_name: 'noaa_75969_DS11.tiff' },
          { ids: { noaa_id: '75969', work_id: 'ft848q83z' }, category: 'successfully_ingested_and_attached', message: 'Supplemental file successfully attached', file_name: 'noaa_75969_DS12.xls' },
          # Work 2: Main file only
          { ids: { noaa_id: '140512', work_id: 'd217qp94n' }, category: 'successfully_ingested_and_attached', message: 'Main PDF successfully attached', file_name: 'noaa_140512_DS1.pdf' },
          # Work 3: Failed attachment
          { ids: { noaa_id: '999999', work_id: 'failed123' }, category: 'failed', message: 'File not found', file_name: 'missing.pdf' }
        ]
      end

      before do
        File.open(attachment_results_path, 'w') do |f|
          input_data.each { |entry| f.puts(entry.to_json) }
        end
      end

      it 'correctly aggregates complex scenario' do
        aggregator.aggregate_results

        expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
          expect(results.size).to eq(4) # Main75969, Supp75969, Main140512, Failed999999

          # Work 75969 supplemental files grouped together
          supp_group = results.find { |r| r[:ids][:noaa_id] == '75969' && r[:message] == 'Supplemental file successfully attached' }
          expect(supp_group[:filenames].size).to eq(3)
          expect(supp_group[:filenames]).to contain_exactly('noaa_75969_DS10.xml', 'noaa_75969_DS11.tiff', 'noaa_75969_DS12.xls')

          # Work 75969 main file separate
          main_group = results.find { |r| r[:ids][:noaa_id] == '75969' && r[:message] == 'Main PDF successfully attached' }
          expect(main_group[:filenames]).to eq(['noaa_75969_DS1.pdf'])

          # Work 140512 standalone
          work2 = results.find { |r| r[:ids][:noaa_id] == '140512' }
          expect(work2[:filenames]).to eq(['noaa_140512_DS1.pdf'])

          # Failed work
          failed = results.find { |r| r[:category] == 'failed' }
          expect(failed[:filenames]).to eq(['missing.pdf'])
        end
      end
    end

    it 'writes with correct mode parameter' do
      File.open(attachment_results_path, 'w') { |f| f.write('') }

      aggregator.aggregate_results

      expect(JsonFileUtilsHelper).to have_received(:write_jsonl).with(anything, output_path, mode: 'w')
    end

    it 'preserves all key fields in output' do
      input = [
        { ids: { noaa_id: '12345', work_id: 'work123' }, category: 'test_category', message: 'test message', file_name: 'file.pdf' }
      ]

      File.open(attachment_results_path, 'w') do |f|
        input.each { |entry| f.puts(entry.to_json) }
      end

      aggregator.aggregate_results

      expect(JsonFileUtilsHelper).to have_received(:write_jsonl) do |results, _path, _options|
        result = results.first
        expect(result).to have_key(:ids)
        expect(result).to have_key(:category)
        expect(result).to have_key(:message)
        expect(result).to have_key(:filenames)
        expect(result[:ids]).to have_key(:noaa_id)
        expect(result[:ids]).to have_key(:work_id)
      end
    end
  end
end
