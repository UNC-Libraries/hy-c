# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  describe '#list_record_info' do
    let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.csv') }
    let!(:file_download_stats) { FactoryBot.create_list(:file_download_stat, 10) }

    before do
      # Ensure the output file is removed before each test
      File.delete(output_path) if File.exist?(output_path)
    end

    it 'writes all records to the output CSV file' do
      service = described_class.new
      service.list_record_info(output_path, nil)

      expect(File).to exist(output_path)

      # Read and parse the CSV file
      csv_data = CSV.read(output_path, headers: true)
      output_records = csv_data.map { |row| row.to_h.symbolize_keys }

      expected_records = file_download_stats.map do |stat|
        {
          id: stat.id.to_s,
          date: stat.date.to_s,
          downloads: stat.downloads.to_s,
          file_id: stat.file_id
        }
      end

      expect(output_records).to match_array(expected_records)
    end

    context 'with an after_timestamp' do
      let(:after_timestamp) { 1.day.ago }
      let!(:recent_stats) { FactoryBot.create_list(:file_download_stat, 3, updated_at: 1.hour.ago) }

      it 'filters records by the given timestamp' do
        # Create a file_download_stat that should not be included
        old_stat = FactoryBot.create(:file_download_stat, updated_at: 2.days.ago)

        service = described_class.new
        service.list_record_info(output_path, after_timestamp)

        expect(File).to exist(output_path)

        # Read and parse the CSV file
        csv_data = CSV.read(output_path, headers: true)
        output_records = csv_data.map { |row| row.to_h.symbolize_keys }

        expected_records = recent_stats.map do |stat|
          {
            id: stat.id.to_s,
            date: stat.date.to_s,
            downloads: stat.downloads.to_s,
            file_id: stat.file_id
          }
        end

        # Ensure old_stat is not included and recent_stats are
        expect(output_records).not_to include(
          id: old_stat.id.to_s,
          date: old_stat.date.to_s,
          downloads: old_stat.downloads.to_s,
          file_id: old_stat.file_id
        )
        expect(output_records).to match_array(expected_records)
      end
    end
  end
end
