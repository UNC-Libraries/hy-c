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

    before do
      allow(concrete_stat_class).to receive(:cached_stats).and_return({cached_stats: :cached_results})
    end

    it 'returns cached stats' do
      # combined_stats is a private method, so have to call with send
      expect(concrete_stat_class.send(:combined_stats, work, start_date, object_method, ga_key, user_id))
          .to eq :cached_results
    end
  end
end
