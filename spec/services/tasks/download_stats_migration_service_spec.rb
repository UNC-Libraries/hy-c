# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  let!(:file_download_stats) { FactoryBot.create_list(:file_download_stat, 10) }
  let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.csv') }
  let(:csv_data) { CSV.read(output_path, headers: true) }
  let(:output_records) { csv_data.map { |row| row.to_h.symbolize_keys } }
  let(:service) { described_class.new }


  before do
    # Ensure the output file is removed before each test
    File.delete(output_path) if File.exist?(output_path)
  end

  describe '#list_record_info' do
    # Helper method to convert an array of FileDownloadStat objects to an array of hashes
    def expected_records_for(stats)
      stats.map do |stat|
        {
          id: stat.id.to_s,
          date: stat.date.to_s,
          downloads: stat.downloads.to_s,
          file_id: stat.file_id
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
      output_records.each do |record|
        hyc_download_stat = HycDownloadStat.find(record[:id])
        expect(hyc_download_stat.date.to_s).to eq(record[:date])
        expect(hyc_download_stat.downloads).to eq(record[:downloads].to_i)
        expect(hyc_download_stat.file_id).to eq(record[:file_id])
      end
    end
  end
end
