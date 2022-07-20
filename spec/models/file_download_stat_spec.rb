require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/models/file_download_stat_override.rb')

RSpec.describe FileDownloadStat, type: :model do
  describe '.ga_statistic' do
    context 'with fileset' do
      let(:user) { FactoryBot.create(:user) }
      let(:work) { Article.create(title: ['New Article']) }
      let(:file_set) { FileSet.new }
      let(:file_set_actor) { Hyrax::Actors::FileSetActor.new(file_set, user) }
      let(:start_date) { 2.days.ago }

      before do
        file_set_actor.attach_to_work(work)
        allow(Hyrax::Analytics).to receive(:profile).and_return(profile)
      end

      context 'when a profile is available' do
        let(:views) { double }
        let(:profile) { double(hyrax__download: views) }

        it 'calls the Legato method with the correct path' do
          expect(views).to receive(:for_file).with(file_set.id)
          described_class.ga_statistics(start_date, file_set)
        end
      end

      context 'when a profile is not available' do
        let(:profile) { nil }

        it 'calls the Legato method with the correct path' do
          expect(described_class.ga_statistics(start_date, file_set)).to be_empty
        end
      end

      context 'with migrated id' do
        let(:views) { double }
        let(:profile) { double(hyrax__download: views) }
        let(:tempfile) { Tempfile.new('redirect_uuids.csv', 'spec/fixtures/') }

        before do
          File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
            f.puts 'uuid,new_path'
            f.puts "bfe93126-849a-43a5-b9d9-391e18ffacc6,parent/#{work.id}/file_sets/#{file_set.id}"
          end
        end

        after do
          tempfile.unlink
          File.delete('spec/fixtures/redirect_uuids.csv') if File.exist?('spec/fixtures/redirect_uuids.csv')
        end

        around do |example|
          cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
          ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
          example.run
          ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
        end

        it 'calls the Legato method with the correct path' do
          expect(views).to receive(:for_file).with("#{file_set.id}|bfe93126-849a-43a5-b9d9-391e18ffacc6")
          described_class.ga_statistics(start_date, file_set)
        end
      end
    end
  end
end
