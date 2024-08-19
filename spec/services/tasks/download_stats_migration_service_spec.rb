# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DownloadStatsMigrationService, type: :service do
  describe '#list_object_ids' do
    let(:output_path) { Rails.root.join('tmp', 'download_migration_test_output.txt') }
    let!(:file_download_stats) { FactoryBot.create_list(:file_download_stat, 10) }

    before do
      # Ensure the output file is removed before each test
      File.delete(output_path) if File.exist?(output_path)
    end

    it 'writes all IDs to the output file' do
      service = described_class.new
      service.list_object_ids(output_path, nil)

      expect(File).to exist(output_path)
      output = File.read(output_path)
      expected_ids = FileDownloadStat.pluck(:id)
      output_ids = output.split("\n").map(&:to_i)

      expect(output_ids).to match_array(expected_ids)
    end

    context 'with an after_timestamp' do
      let(:after_timestamp) { 1.day.ago }
      let!(:recent_stats) { FactoryBot.create_list(:file_download_stat, 3, updated_at: 1.hour.ago) }

      it 'filters records by the given timestamp' do
        # Create a file_download_stat that should not be included
        old_stat = FactoryBot.create(:file_download_stat, updated_at: 2.days.ago)

        service = described_class.new
        service.list_object_ids(output_path, after_timestamp)

        output = File.read(output_path)
        expected_ids = recent_stats.pluck(:id)
        output_ids = output.split("\n").map(&:to_i)

        expect(output_ids).not_to include(old_stat.id)
        expect(output_ids).to match_array(expected_ids)
      end
    end
  end
end
