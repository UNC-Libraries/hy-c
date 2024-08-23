# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  let(:admin_set_title) { 'Open_Access_Articles_and_Book_Chapters' }
  let(:mock_admin_set) { FactoryBot.create(:solr_query_result, :admin_set, title_tesim: [admin_set_title]) }
  let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.csv') }
  # let(:csv_data) { CSV.read(output_path, headers: true) }
  # let(:output_records) { csv_data.map { |row| row.to_h.symbolize_keys } }
  let(:service) { described_class.new }

  before do
    # Ensure the output file is removed before each test
    File.delete(output_path) if File.exist?(output_path)
    allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_title}", rows: 1).and_return('response' => { 'docs' => [mock_admin_set] })
  end

  describe '#list_record_info' do
    before do
      @file_download_stats = [
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
      @mock_works = @file_download_stats.map { |stat| FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: [stat.file_id]) }
      @file_download_stats.each_with_index do |stat, index|
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [@mock_works[index]] })
      end
    end

    it 'writes all records to the output CSV file' do
      service.list_record_info(output_path, nil)

      expect(File).to exist(output_path)
      expect(csv_to_hash_array(output_path)).to match_array(expected_records_for(@file_download_stats))
    end

    context 'with an after_timestamp' do
      let(:after_timestamp) { 1.day.ago }
      let!(:recent_stats) { FactoryBot.create_list(:file_download_stat, 3, updated_at: 1.hour.ago) }
      let!(:old_stat) { FactoryBot.create(:file_download_stat, updated_at: 2.days.ago) }

      it 'filters records by the given timestamp' do
        service.list_record_info(output_path, after_timestamp)

        expect(File).to exist(output_path)
        expect(csv_to_hash_array(output_path)).not_to include(expected_records_for([old_stat]).first)
        expect(csv_to_hash_array(output_path)).to match_array(expected_records_for(recent_stats))
      end
    end
  end

  describe '#migrate_to_new_table' do
    before do
        # Smaller groups to enable easier testing for aggregation of download stats from daily to monthly
      @file_download_stats = [[
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 15), downloads: 10, file_id: 'file_id_1'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 30), downloads: 10, file_id: 'file_id_1'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 3, 15), downloads: 10, file_id: 'file_id_1'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 3, 30), downloads: 10, file_id: 'file_id_1'),
      ],
      [
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 4, 15), downloads: 10, file_id: 'file_id_2'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 4, 30), downloads: 10, file_id: 'file_id_2'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 5, 15), downloads: 10, file_id: 'file_id_2'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 5, 30), downloads: 10, file_id: 'file_id_2'),
      ],
      [
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 15), downloads: 10, file_id: 'file_id_3'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 30), downloads: 10, file_id: 'file_id_3'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 7, 15), downloads: 10, file_id: 'file_id_3'),
        FactoryBot.create(:file_download_stat, date: Date.new(2023, 7, 30), downloads: 10, file_id: 'file_id_3'),
      ]]
      @mock_works = @file_download_stats.flatten.map do |stat|
        FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: [stat.file_id])
      end
      @file_download_stats.flatten.each_with_index do |stat, index|
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [@mock_works[index]] })
      end
      service.list_record_info(output_path, nil)
      service.migrate_to_new_table(output_path)
    end

    it 'creates new HycDownloadStat records from the CSV file' do
      csv_to_hash_array(output_path).each_with_index do |record, index|
        # puts 'All HycDownloadStat records:'
        # HycDownloadStat.all.each do |stat|
        #   puts "ID: #{stat.id}, File ID: #{stat.fileset_id}, Date: #{stat.date}, Downloads: #{stat.download_count}"
        # end
        # puts "Record: #{record.inspect}"
        # hyc_download_stat = HycDownloadStat.find(record[:id])
        work_data = WorkUtilsHelper.fetch_work_data_by_fileset_id(record[:file_id])
        hyc_download_stat = HycDownloadStat.find_by(fileset_id: record[:file_id], date: record[:date].to_date.beginning_of_month)
        
        expect(hyc_download_stat).to be_present
        expect(hyc_download_stat.fileset_id).to eq(record[:file_id])
        expect(hyc_download_stat.work_id).to eq(work_data[:work_id])
        expect(hyc_download_stat.date).to eq(record[:date].to_date)
        # Each mocked record has 10 downloads per month, so the download count should be 20
        expect(hyc_download_stat.download_count).to eq(20)
      end
    end
  end

  private
  def csv_to_hash_array(file_path)
    CSV.read(file_path, headers: true).map { |row| row.to_h.symbolize_keys }
  end

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
end
