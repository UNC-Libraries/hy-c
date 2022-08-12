require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/models/file_download_stat_override.rb')

RSpec.describe FileDownloadStat, type: :model do
  let(:file_set) { FactoryBot.create(:file_set) }

  context 'with redirect mappings' do
    let(:tempfile) { Tempfile.new('redirect_uuids.csv', 'spec/fixtures/') }
    before do
      File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
        f.puts 'uuid,new_path'
        f.puts "bfe93126-849a-43a5-b9d9-391e18ffacc6,parent/bc111t81q/file_sets/#{file_set.id}"
      end
    end

    after do
      tempfile.unlink
      File.delete('spec/fixtures/redirect_uuids.csv') if File.exist?('spec/fixtures/redirect_uuids.csv')
    end

    around do |example|
      Rails.cache.clear
      cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
      ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
      example.run
      ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
    end

    describe '.as_subject' do
      it 'returns subject with old and new id' do
        expect(described_class.as_subject(file_set).id).to eq "#{file_set.id}|bfe93126-849a-43a5-b9d9-391e18ffacc6"
      end

      context 'file that does not have a redirect' do
        let(:file_set2) { FactoryBot.create(:file_set) }

        it 'returns subject with only new id' do
          expect(described_class.as_subject(file_set2).id).to eq file_set2.id
        end
      end
    end

    describe '.ga_statistic' do
      let(:start_date) { 2.days.ago }
      let(:file_set2) { FactoryBot.create(:file_set) }

      before do
        allow(described_class).to receive(:original_ga_statistics)
      end

      it 'calls wrapper method succeed' do
        described_class.ga_statistics(start_date, file_set2)
      end
    end
  end
end
