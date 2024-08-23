# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  let!(:file_download_stats) do
    [
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 1)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 15)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 30)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 1)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 15)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 30)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 12, 1)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 12, 15)),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 12, 30))
    ]
  end
  let(:admin_set_title) { 'Open_Access_Articles_and_Book_Chapters' }
  let!(:mock_admin_set) { FactoryBot.create(:solr_query_result) }
  # Generate works for the each file_download_stat
  let!(:mock_works) { file_download_stats.map { |stat| FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: [stat.file_id]) } }
  let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.csv') }
  let(:csv_data) { CSV.read(output_path, headers: true) }
  let(:output_records) { csv_data.map { |row| row.to_h.symbolize_keys } }
  let(:service) { described_class.new }


  before do
    # Ensure the output file is removed before each test
    File.delete(output_path) if File.exist?(output_path)
    allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_title}", rows: 1).and_return('response' => { 'docs' => [mock_admin_set] })
    file_download_stats.each_with_index do |stat, index|
      # Assign a random number of downloads to each stat
      puts "Stat file_id: #{stat.file_id}"
      allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [mock_works[index]] })
    end
  end

  describe '#list_record_info' do
    # Helper method to convert an array of FileDownloadStat objects to an array of hashes
    # Checks for truncated date to the beginning of the month
    def expected_records_for(stats)
      stats.map do |stat|
        {
          file_id: stat.file_id,
          date: stat.date.beginning_of_month.to_s,
          downloads: stat.downloads.to_s,
        }
      end
    end

    it 'writes all records to the output CSV file' do
      service.list_record_info(output_path, nil)

      expect(File).to exist(output_path)
      expect(output_records).to match_array(expected_records_for(file_download_stats))
    end

    context 'with an after_timestamp' do
      let(:after_timestamp) { 1.day.ago }
      let!(:recent_stats) { FactoryBot.create_list(:file_download_stat, 3, updated_at: 1.hour.ago) }
      let!(:old_stat) { FactoryBot.create(:file_download_stat, updated_at: 2.days.ago) }

      it 'filters records by the given timestamp' do
        service.list_record_info(output_path, after_timestamp)

        expect(File).to exist(output_path)
        expect(output_records).not_to include(expected_records_for([old_stat]).first)
        expect(output_records).to match_array(expected_records_for(recent_stats))
      end
    end
  end

  describe '#migrate_to_new_table' do
    before do
      service.list_record_info(output_path, nil)
      service.migrate_to_new_table(output_path)
    end

    it 'creates new HycDownloadStat records from the CSV file' do
      output_records.each_with_index do |record,index|
        # WIP: Break at index 5
        if index == 5
          break
        end
        puts "Record: #{record.inspect}"
        hyc_download_stat = HycDownloadStat.find(record[:id])
        expect(hyc_download_stat.date.to_s).to eq(record[:date])
        expect(hyc_download_stat.downloads).to eq(record[:downloads].to_i)
        expect(hyc_download_stat.file_id).to eq(record[:file_id])
      end
    end
  end
end
