require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/models/hyrax/statistic_override.rb')

RSpec.describe Hyrax::Statistic, type: :model do
  let(:concrete_stat_class) do
    Class.new(Hyrax::Statistic) do
      self.cache_column = :downloads
      self.event_type = :totalEvents

      def filter(file)
        { file_id: file.id }
      end
    end
  end
  let(:date) { Time.current }

  describe '.ga_statistic' do
    context 'with fileset' do
      let(:views) { double }
      let(:profile) { double(hyrax__pageview: views) }

      let(:user) { FactoryBot.create(:user) }
      let(:work) { Article.create(title: ['New Article']) }
      let(:file_set) { FileSet.new }
      let(:file_set_actor) { Hyrax::Actors::FileSetActor.new(file_set, user) }
      let(:start_date) { 2.days.ago }

      before do
        file_set_actor.attach_to_work(work)
        allow(Hyrax::Analytics).to receive(:profile).and_return(profile)
      end

      after do
        HycHelper.clear_redirect_mapping
      end

      context 'when a profile is available' do
        it 'calls the Legato method with the correct path' do
          expect(views).to receive(:for_path).with("/concern/file_sets/#{file_set.id}")
          concrete_stat_class.ga_statistics(start_date, file_set)
        end
      end

      context 'when a profile is not available' do
        let(:profile) { nil }

        it 'calls the Legato method with the correct path' do
          expect(concrete_stat_class.ga_statistics(start_date, file_set)).to be_empty
        end
      end

      context 'with migrated id' do
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
          HycHelper.clear_redirect_mapping
          cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
          ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
          example.run
          ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
          HycHelper.clear_redirect_mapping
        end

        it 'calls the Legato method with the correct path' do
          expect(views).to receive(:for_path).with("/concern/file_sets/#{file_set.id}|/record/uuid:bfe93126-849a-43a5-b9d9-391e18ffacc6")
          concrete_stat_class.ga_statistics(start_date, file_set)
        end
      end
    end
  end

  describe '#statistics' do
    let(:test_class) { WorkViewStat }
    let(:user) { FactoryBot.create(:user) }
    let(:user_id) { user.id }
    let(:work) { Article.create(title: ['New Article']) }
    let(:work_id) { work.id }

    let(:dates) do
      ldates = []
      4.downto(0) { |idx| ldates << (Time.zone.today - idx.day) }
      ldates
    end
    let(:date_strs) do
      dates.map { |date| date.strftime('%Y%m%d') }
    end

    let(:view_output) do
      [[statistic_date(dates[0]), 4], [statistic_date(dates[1]), 8], [statistic_date(dates[2]), 6], [statistic_date(dates[3]), 10]]
    end

    # This is what the data looks like that's returned from Google Analytics (GA) via the Legato gem
    # Due to the nature of querying GA, testing this data in an automated fashion is problematc.
    # Sample data structures were created by sending real events to GA from a test instance of
    # Scholarsphere.  The data below are essentially a "cut and paste" from the output of query
    # results from the Legato gem.
    let(:sample_work_pageview_statistics) do
      [
        SpecStatistic.new(date: date_strs[0], pageviews: 4),
        SpecStatistic.new(date: date_strs[1], pageviews: 8),
        SpecStatistic.new(date: date_strs[2], pageviews: 6),
        SpecStatistic.new(date: date_strs[3], pageviews: 10)
      ]
    end

    # from https://github.com/samvera/hyrax/blob/v2.9.6/spec/models/work_view_stat_spec.rb
    describe 'cache loaded' do
      let!(:work_view_stat) { test_class.create(date: (Time.zone.today - 5.days).to_datetime, work_id: work_id, work_views: '25') }

      let(:stats) do
        expect(test_class).to receive(:ga_statistics).and_return(sample_work_pageview_statistics)
        test_class.statistics(work, Time.zone.today - 5.days)
      end

      it 'includes cached data' do
        # Verify that the stats, converted to a list of points, contains the expected number of views for the correct timestamp
        expect(stats.map(&:to_flot)).to include([work_view_stat.date.to_i * 1000, work_view_stat.work_views], *view_output)
      end
    end

    # This is a test for error handling override
    describe 'request for statistics times out' do
      let(:views) { double }
      let(:profile) { double(hyrax__pageview: views) }

      before do
        allow(Hyrax::Analytics).to receive(:profile).and_raise(Net::ReadTimeout)
      end

      it 'logs and handles error' do
        expect(Rails.logger).to receive(:warn).with("Unable to retrieve GA stats for #{work_id}. Request timed out. Using cached stats for object.")
        test_class.statistics(work, Time.zone.today - 4.days, user_id)
      end
    end
  end
end

# https://github.com/samvera/hyrax/blob/v2.9.6/spec/support/spec_statistic.rb
class SpecStatistic
  def initialize(**kargs)
    @attributes = kargs.symbolize_keys
  end

  def [](key)
    @attributes[key.to_sym]
  end

  def method_missing(method_name, *arguments, &block)
    if @attributes.key?(method_name.to_sym)
      @attributes[method_name]
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @attributes.key?(method_name.to_sym) || super
  end
end

def statistic_date(date)
  date.to_datetime.to_i * 1000
end
