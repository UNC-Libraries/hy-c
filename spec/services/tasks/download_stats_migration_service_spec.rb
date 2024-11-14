# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  let(:admin_set_title) { 'Open_Access_Articles_and_Book_Chapters' }
  let(:mock_admin_set) { FactoryBot.create(:solr_query_result, :admin_set, title_tesim: [admin_set_title]) }
  let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.csv') }
  let(:service) { described_class.new }
  let(:spec_base_analytics_url) { 'https://analytics-qa.lib.unc.edu' }
  let(:spec_site_id) { '5' }
  let(:spec_auth_token) { 'testtoken' }
  let(:matomo_stats_migration_fixture) do
    JSON.parse(File.read(File.join(Rails.root, '/spec/fixtures/files/matomo_stats_migration_fixture.json')))
  end

  around do |example|
    # Set the environment variables for the test
    @auth_token = ENV['MATOMO_AUTH_TOKEN']
    @site_id = ENV['MATOMO_SITE_ID']
    @matomo_base_url = ENV['MATOMO_BASE_URL']
    ENV['MATOMO_AUTH_TOKEN'] = spec_auth_token
    ENV['MATOMO_SITE_ID'] = spec_site_id
    ENV['MATOMO_BASE_URL'] = spec_base_analytics_url
    example.run
    # Reset the environment variables
    ENV['MATOMO_AUTH_TOKEN'] = @auth_token
    ENV['MATOMO_SITE_ID'] = @site_id
    ENV['MATOMO_BASE_URL'] = @matomo_base_url
  end

  before do
    allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_title}", { :rows => 1, 'df' => 'title_tesim'}).and_return('response' => { 'docs' => [mock_admin_set] })
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

  describe '#list_work_stat_info' do
    # Loop through each source to test the listing of work stats
    [Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO,
    Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE,
    Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4].each do |source|
      context "when the source is #{source}" do
        before do
          test_setup_for(source)
        end

        it 'writes all works to the output CSV file' do
          expected_stats = setup_expected_stats_for(source)
          list_work_stat_info_for(source)
          expect(File).to exist(output_path)
          if source == Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4
            FileUtils.cp(output_path, Rails.root.join('tmp', 'download_migration_test_output_ga4.csv'))
          end
          expect(csv_to_hash_array(output_path)).to match_array(expected_stats)
        end

        # Run this test only when the source is CACHE
        if source == Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE
          it 'handles and logs errors' do
            allow(Rails.logger).to receive(:error)
            allow(FileDownloadStat).to receive(:all).and_raise(StandardError, 'Simulated database query failure')
            service.list_work_stat_info(output_path, Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE)
            expect(Rails.logger).to have_received(:error).with('An error occurred while listing work stats: Simulated database query failure')
          end
        end
      end
    end

    # Excluded from the source loop since it focuses on the after_timestamp parameter
    context 'with an after_timestamp (for cache migration only)' do
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

      it 'filters works by the given after_timestamp' do
        service.list_work_stat_info(output_path, Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE, after_timestamp: '2023-04-06 00:00:00 UTC')
        expect(File).to exist(output_path)
        expect(csv_to_hash_array(output_path).map { |work| work[:file_id] }).to match_array(recent_stat_file_ids)
        expect(csv_to_hash_array(output_path).map { |work| work[:file_id] }).not_to include(*old_stat_file_ids)
      end
    end

    context 'with an unsupported source' do
      it 'handles and logs an error' do
        allow(Rails.logger).to receive(:error)
        service.list_work_stat_info(output_path, :unsupported_source)
        expect(Rails.logger).to have_received(:error).with('An error occurred while listing work stats: Unsupported source: unsupported_source')
      end
    end
  end

  describe '#migrate_to_new_table' do
    # Loop through each source to test the listing of work stats
    [Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO,
    Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4,
    Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE].each do |source|
      context "when the source is #{source}" do
        before do
          test_setup_for(source)
        end
        after { HycDownloadStat.delete_all }

        let (:expected_stats) { setup_expected_stats_for(source) }

        it 'creates new HycDownloadStat works from the CSV file' do
          list_work_stat_info_for(source)
          service.migrate_to_new_table(output_path)
          csv_to_hash_array(output_path).each_with_index do |csv_row, index|
            work_data = WorkUtilsHelper.fetch_work_data_by_fileset_id(csv_row[:file_id])
            csv_row_date = Date.parse(csv_row[:date]).beginning_of_month
            hyc_download_stat = HycDownloadStat.find_by(fileset_id: csv_row[:file_id], date: csv_row_date)

            expect(hyc_download_stat).to be_present
            expect(hyc_download_stat.fileset_id).to eq(csv_row[:file_id])
            expect(hyc_download_stat.work_id).to eq(work_data[:work_id] || 'Unknown')
            expect(hyc_download_stat.date).to eq(csv_row[:date].to_date)

           # Verify the download count is correct
            expected_stat = expected_stats.find { |work| work[:file_id] == csv_row[:file_id] && work[:date] == csv_row[:date] }
            expected_download_count = expected_stat[:downloads].to_i
            expect(hyc_download_stat.download_count).to eq(expected_download_count)
          end
        end

        it 'retains historic stats for a work even if the work cannot be found in solr' do
          # Define the range based on the source
          index_range = source == Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4 ? (1..7) : (1..6)

          # Mock the solr query to return a mostly empty response for each test file_set_id in the defined range
          index_range.each do |index|
            allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:file_id_#{index}", rows: 1).and_return('response' => { 'docs' => [] })
            allow(ActiveFedora::SolrService).to receive(:get).with("id:file_id_#{index}", rows: 1).and_return('response' => { 'docs' => [] })
          end

          list_work_stat_info_for(source)
          service.migrate_to_new_table(output_path)
          csv_to_hash_array(output_path).each_with_index do |csv_row, index|
            hyc_download_stat = HycDownloadStat.find_by(fileset_id: csv_row[:file_id], date: Date.parse(csv_row[:date]).beginning_of_month)
            expect(hyc_download_stat).to be_present
            expect(hyc_download_stat.fileset_id).to eq(csv_row[:file_id])
            expect(hyc_download_stat.work_id).to eq('Unknown')
            expect(hyc_download_stat.admin_set_id).to eq('Unknown')
            expect(hyc_download_stat.work_type).to eq('Unknown')
            expect(hyc_download_stat.date).to eq(csv_row[:date].to_date)

            # Verify the download count is correct
            expected_stat = expected_stats.find { |work| work[:file_id] == csv_row[:file_id] && work[:date] == csv_row[:date] }
            expected_download_count = expected_stat[:downloads].to_i
            expect(hyc_download_stat.download_count).to eq(expected_download_count)
          end
        end

        it 'handles and logs errors' do
          allow(CSV).to receive(:read).and_raise(StandardError, 'Simulated CSV read failure')
          allow(Rails.logger).to receive(:error)
          service.migrate_to_new_table(output_path)
          expect(Rails.logger).to have_received(:error).with('An error occurred while migrating work stats: Simulated CSV read failure')
        end
      end
    end

    # Excluding this portion of tests from the source loop as the error handling is the same for all sources
    context 'if a failure occurs during a private function' do
      before do
        test_setup_for(Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE)
        service.list_work_stat_info(output_path,  Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE)
      end

      it 'handles and logs errors from create_hyc_download_stat' do
        allow(Rails.logger).to receive(:error)
        # Simulate a failure during the creation of a HycDownloadStat object for a specific file_id
        allow(HycDownloadStat).to receive(:find_or_initialize_by).and_call_original
        allow(HycDownloadStat).to receive(:find_or_initialize_by).with({date: '2023-03-01 00:00:00 UTC', fileset_id: 'file_id_1'}).and_raise(StandardError, 'Simulated database query failure').once
        service.migrate_to_new_table(output_path)
        expect(Rails.logger).to have_received(:error).with(a_string_including('Failed to create HycDownloadStat for'))
      end

      it 'handles and logs errors from save_hyc_download_stat' do
        allow(Rails.logger).to receive(:error)
        # Simulate a failure during the saving of a HycDownloadStat object for a specific file_id
        allow_any_instance_of(HycDownloadStat).to receive(:new_record?).and_raise(StandardError, 'Simulated save failure')
        service.migrate_to_new_table(output_path)
        expect(Rails.logger).to have_received(:error).with(a_string_including('Error saving new row to HycDownloadStat')).at_least(1).times
      end
    end
  end


  private
  def test_setup_for(source)
    case source
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO
      # Mocking Matomo API responses based on the fixture data
      matomo_stats_migration_fixture.each do |month, stats|
        stub_request(:get, "#{ENV['MATOMO_BASE_URL']}/index.php")
          .with(query: hash_including({ 'date' => month }))
          .to_return(status: 200, body: stats.to_json, headers: { 'Content-Type' => 'application/json' })
      end
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4
    else
      raise ArgumentError, "Unsupported source: #{source}"
    end
    stub_solr_query_results_for(source)
  end

  def stub_solr_query_results_for(source)
    case source
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE
        # Use mocked file_download_stats to create works for each file_set_id
      mock_works = file_download_stats.flatten.map do |stat|
        FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: [stat.file_id])
      end
        # Mock query responses for each file_set_id with the corresponding work
      file_download_stats.flatten.each_with_index do |stat, index|
        mock_work = mock_works[index]

        mock_work_with_admin_set = mock_work.dup
        mock_work_with_admin_set['admin_set_tesim'] = [admin_set_title]
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{stat.file_id}", rows: 1).and_return('response' => { 'docs' => [mock_work_with_admin_set] })
      end
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO
       # Mock query responses for file_set_ids 1-6
      mock_works_for_file_id_numbers((1..6).to_a)
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4
       # Mock query responses for file_set_ids 1-7
      mock_works_for_file_id_numbers((1..7).to_a)
    else
      raise ArgumentError, "Unsupported source: #{source}"
    end
  end

  def mock_works_for_file_id_numbers(file_id_numbers)
    mock_works = file_id_numbers.map do |num|
      FactoryBot.create(:solr_query_result, :work, file_set_ids_ssim: ["file_id_#{num}"])
    end
    file_id_numbers.each_with_index do |num, index|
      allow(ActiveFedora::SolrService).to receive(:get).with("id:file_id_#{num}", rows: 1).and_return('response' => { 'docs' => [mock_works[index]] })
      allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:file_id_#{num}", rows: 1).and_return('response' => { 'docs' => [mock_works[index]] })
    end
  end

  def setup_expected_stats_for(source)
    expected_stats = []
    case source
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE
      expected_stats = [
              { file_id: 'file_id_1', date: '2023-01-01 00:00:00 UTC', downloads: '10' },
              { file_id: 'file_id_1', date: '2023-03-01 00:00:00 UTC', downloads: '20' },
              { file_id: 'file_id_2', date: '2023-04-01 00:00:00 UTC', downloads: '50' },
              { file_id: 'file_id_2', date: '2023-05-01 00:00:00 UTC', downloads: '100' },
              { file_id: 'file_id_3', date: '2023-06-01 00:00:00 UTC', downloads: '200' },
              { file_id: 'file_id_3', date: '2023-07-01 00:00:00 UTC', downloads: '300' }
            ]
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO
      expected_stats = [
              { file_id: 'file_id_1', date: '2024-01-01', downloads: '190' },
              { file_id: 'file_id_2', date: '2024-01-01', downloads: '150' },
              { file_id: 'file_id_3', date: '2024-02-01', downloads: '100' },
              { file_id: 'file_id_4', date: '2024-02-01', downloads: '80' },
              { file_id: 'file_id_5', date: '2024-03-01', downloads: '180' },
              { file_id: 'file_id_6', date: '2024-03-01', downloads: '550' }
            ]
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4
      expected_stats = [
              { file_id: 'file_id_1', date: '2023-09-01', downloads: '506' },
              { file_id: 'file_id_2', date: '2023-09-01', downloads: '457' },
              # Using file_id_3 as a test case for aggregation of multiple months of data
              { file_id: 'file_id_3', date: '2023-09-01', downloads: '2' },
              { file_id: 'file_id_3', date: '2024-01-01', downloads: '5' },
              { file_id: 'file_id_3', date: '2024-03-01', downloads: '8' },
              { file_id: 'file_id_4', date: '2024-01-01', downloads: '503' },
              { file_id: 'file_id_5', date: '2024-01-01', downloads: '262' },
              { file_id: 'file_id_6', date: '2024-03-01', downloads: '1505' },
              { file_id: 'file_id_7', date: '2024-03-01', downloads: '822' }
            ]
    end
    expected_stats
  end

  def csv_to_hash_array(file_path)
    CSV.read(file_path, headers: true).map { |row| row.to_h.symbolize_keys }
  end

  # Execute the list_work_stat_info method for the given source with predefined timestamp parameters
  def list_work_stat_info_for(source)
    case source
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE
      service.list_work_stat_info(output_path, Tasks::DownloadStatsMigrationService::DownloadMigrationSource::CACHE)
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO
      service.list_work_stat_info(output_path, Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO, after_timestamp: '2024-01-01', before_timestamp: '2024-03-01')
    when Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4
      service.list_work_stat_info(output_path, Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4, ga_stats_dir: File.join(Rails.root, '/spec/fixtures/csv/ga4_stats'))
    end
  end
end
