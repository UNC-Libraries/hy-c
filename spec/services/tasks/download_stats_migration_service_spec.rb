# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  let(:admin_set_title) { 'Open_Access_Articles_and_Book_Chapters' }
  let(:mock_admin_set) { FactoryBot.create(:solr_query_result, :admin_set, title_tesim: [admin_set_title]) }
  let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.csv') }
  let(:service) { described_class.new }

  before do
    allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_title}", rows: 1).and_return('response' => { 'docs' => [mock_admin_set] })
  end

  after do
    # Ensure the output file is removed after each test
    File.delete(output_path) if File.exist?(output_path)
  end

  # Smaller groups to allow for easier testing for aggregation of download stats from daily to monthly
  let(:file_download_stats) { [[
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 15), downloads: 5, file_id: 'file_id_1'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 1, 30), downloads: 5, file_id: 'file_id_1'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 3, 15), downloads: 10, file_id: 'file_id_1'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 3, 30), downloads: 10, file_id: 'file_id_1'),
 ],
 [
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 4, 15), downloads: 25, file_id: 'file_id_2'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 4, 30), downloads: 25, file_id: 'file_id_2'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 5, 15), downloads: 50, file_id: 'file_id_2'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 5, 30), downloads: 50, file_id: 'file_id_2'),
 ],
 [
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 15), downloads: 100, file_id: 'file_id_3'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 6, 30), downloads: 100, file_id: 'file_id_3'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 7, 15), downloads: 150, file_id: 'file_id_3'),
   FactoryBot.create(:file_download_stat, date: Date.new(2023, 7, 30), downloads: 150, file_id: 'file_id_3'),
 ]]
  }

  # Create a hash of [fileset_id, date.beginning_of_month] => download count for each file_download_stats
  let(:expected_aggregated_download_count) do
    file_download_stats.flatten.each_with_object(Hash.new(0)) do |stat, hash|
      hash[[stat.file_id, stat.date.beginning_of_month.to_datetime]] += stat.downloads
    end
  end

  let(:mock_works) do
    file_download_stats.flatten.map do |stat|
      FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: [stat.file_id])
    end
  end

  describe '#list_work_stat_info' do
    it 'writes all works to the output CSV file' do
      file_download_stats.flatten.each_with_index do |stat, index|
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [mock_works[index]] })
      end

      expected_works = [
        { file_id: 'file_id_1', date: '2023-01-01 00:00:00 UTC', downloads: '10' },
        { file_id: 'file_id_1', date: '2023-03-01 00:00:00 UTC', downloads: '20' },
        { file_id: 'file_id_2', date: '2023-04-01 00:00:00 UTC', downloads: '50' },
        { file_id: 'file_id_2', date: '2023-05-01 00:00:00 UTC', downloads: '100' },
        { file_id: 'file_id_3', date: '2023-06-01 00:00:00 UTC', downloads: '200' },
        { file_id: 'file_id_3', date: '2023-07-01 00:00:00 UTC', downloads: '300' }
      ]
      service.list_work_stat_info(output_path, nil)

      expect(File).to exist(output_path)
      expect(csv_to_hash_array(output_path)).to match_array(expected_works)
    end

    it 'handles and logs errors' do
      allow(Rails.logger).to receive(:error)
      allow(FileDownloadStat).to receive(:all).and_raise(StandardError, 'Simulated database query failure')
      service.list_work_stat_info(output_path, nil)
      expect(Rails.logger).to have_received(:error).with('An error occurred while listing work stats: Simulated database query failure')
    end

    context 'with an after_timestamp' do
      let(:recent_stats) { FactoryBot.create_list(:file_download_stat, 3, updated_at: '2023-05-05 00:00:00 UTC') }
      let(:old_stats) { FactoryBot.create_list(:file_download_stat, 3, updated_at: '2023-04-05 00:00:00 UTC') }
      let(:recent_stat_file_ids) { recent_stats.map(&:file_id) }
      let(:old_stat_file_ids) { old_stats.map(&:file_id) }

      before do
        all_stats = recent_stats + old_stats
        all_works = all_stats.map do |stat|
          FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: [stat.file_id])
        end
        all_stats.each_with_index do |stat, index|
          allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [all_works[index]] })
        end
      end

      it 'filters works by the given timestamp' do
        # Retrieve works created after 'updated_at' date for old stats
        service.list_work_stat_info(output_path, '2023-04-06 00:00:00 UTC')
        puts "CSV data: #{csv_to_hash_array(output_path).inspect}"

        expect(File).to exist(output_path)
        expect(csv_to_hash_array(output_path).map { |work| work[:file_id] }).to match_array(recent_stat_file_ids)
        expect(csv_to_hash_array(output_path).map { |work| work[:file_id] }).not_to include(*old_stat_file_ids)
      end
    end
  end

  describe '#migrate_to_new_table' do
    before do
      file_download_stats.flatten.each_with_index do |stat, index|
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [mock_works[index]] })
      end
      service.list_work_stat_info(output_path, nil)
      service.migrate_to_new_table(output_path)
    end

    it 'creates new HycDownloadStat works from the CSV file' do
      csv_to_hash_array(output_path).each_with_index do |csv_row, index|
        work_data = WorkUtilsHelper.fetch_work_data_by_fileset_id(csv_row[:file_id])
        csv_row_date = Date.parse(csv_row[:date]).beginning_of_month
        hyc_download_stat = HycDownloadStat.find_by(fileset_id: csv_row[:file_id], date: csv_row_date)

        expect(hyc_download_stat).to be_present
        expect(hyc_download_stat.fileset_id).to eq(csv_row[:file_id])
        expect(hyc_download_stat.work_id).to eq(work_data[:work_id])
        expect(hyc_download_stat.date).to eq(csv_row[:date].to_date)
        expect(hyc_download_stat.download_count).to eq(expected_aggregated_download_count[[csv_row[:file_id], csv_row_date]])
      end
    end

    it 'handles and logs errors' do
      allow(CSV).to receive(:read).and_raise(StandardError, 'Simulated CSV read failure')
      allow(Rails.logger).to receive(:error)
      service.migrate_to_new_table(output_path)
      expect(Rails.logger).to have_received(:error).with('An error occurred while migrating work stats: Simulated CSV read failure')
    end

    context 'if a failure occurs during a private function' do
      it 'handles and logs errors from create_hyc_download_stat' do
        allow(Rails.logger).to receive(:error)
        # Simulate a failure during the creation of a HycDownloadStat object for a specific file_id
        allow(HycDownloadStat).to receive(:find_or_initialize_by).and_call_original
        allow(HycDownloadStat).to receive(:find_or_initialize_by).with({:date=>"2023-03-01 00:00:00 UTC", :fileset_id=>"file_id_1"}).and_raise(StandardError, 'Simulated database query failure')
        service.migrate_to_new_table(output_path)
        expect(Rails.logger).to have_received(:error).with(a_string_including('Failed to create HycDownloadStat for'))
      end

      it 'handles and logs errors from save_hyc_download_stat' do
        allow(Rails.logger).to receive(:error)
        # Simulate a failure during the creation of a HycDownloadStat object for a specific file_id
        allow(HycDownloadStat).to receive(:find_or_initialize_by).and_call_original
        allow(HycDownloadStat).to receive(:find_or_initialize_by).with({:date=>"2023-03-01 00:00:00 UTC", :fileset_id=>"file_id_1"}).and_raise(StandardError, 'Simulated database query failure')
        service.migrate_to_new_table(output_path)
        expect(Rails.logger).to have_received(:error).with(a_string_including('Failed to create HycDownloadStat for'))
      end
    end
  end


  private
  def csv_to_hash_array(file_path)
    CSV.read(file_path, headers: true).map { |row| row.to_h.symbolize_keys }
  end

  # Helper method to convert an array of FileDownloadStat objects to an array of hashes
  # Checks for truncated date to the beginning of the month
  def expected_works_for(stats)
    stats.map do |stat|
      {
        file_id: stat.file_id,
        date: stat.date.beginning_of_month.to_s,
        downloads: stat.downloads.to_s,
      }
    end
  end
end
