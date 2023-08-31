# frozen_string_literal: true
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/models/hyrax/statistic_override.rb')

RSpec.describe Hyrax::Statistic, type: :model do
  before do
    ActiveFedora::Cleaner.clean!
  end

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

  describe '.combined_stats' do
    let(:user_id) { 'user12345' }
    let(:work) { Article.create(title: ['New Article']) }
    let(:start_date) { Time.zone.today }
    let(:object_method) { 'method' }
    let(:ga_key) { 'secret' }

    context 'no exception encountered' do
      before do
        allow(concrete_stat_class).to receive(:original_combined_stats).and_return(:normal_results)
      end

      it 'returns stats from the original method' do
        # combined_stats is a private method, so have to call with send
        expect(concrete_stat_class.send(:combined_stats, work, start_date, object_method, ga_key, user_id))
            .to eq :normal_results
      end
    end

    context 'timeout encountered' do
      before do
        # Clear the cached value between runs, since it is a class variable
        concrete_stat_class.raise_timeouts = nil
        allow(concrete_stat_class).to receive(:original_combined_stats).and_raise(Net::ReadTimeout)
        allow(concrete_stat_class).to receive(:cached_stats).and_return({cached_stats: :cached_results})
      end

      context 'with timeout behavior set to default' do
        around do |example|
          original = ENV['ANALYTICS_RAISE_TIMEOUTS']
          ENV.delete('ANALYTICS_RAISE_TIMEOUTS')
          example.run
          ENV['ANALYTICS_RAISE_TIMEOUTS'] = original
        end

        it 'returns cached stats' do
          # combined_stats is a private method, so have to call with send
          expect(concrete_stat_class.send(:combined_stats, work, start_date, object_method, ga_key, user_id))
              .to eq :cached_results
        end
      end

      context 'with timeouts set to raise' do
        around do |example|
          original = ENV['ANALYTICS_RAISE_TIMEOUTS']
          ENV['ANALYTICS_RAISE_TIMEOUTS'] = 'true'
          example.run
          ENV['ANALYTICS_RAISE_TIMEOUTS'] = original
        end

        it 'throws the error' do
          # combined_stats is a private method, so have to call with send
          expect { concrete_stat_class.send(:combined_stats, work, start_date, object_method, ga_key, user_id) }.to raise_error(Net::ReadTimeout)
        end
      end
    end
  end
end
