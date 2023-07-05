# frozen_string_literal: true
namespace 'hyc' do
  desc 'Update analytics statistics cache'
  task update_stats_cache: :environment do
    # Force legato model and other stats classes to eager load, they must already be present for method generation and concurrent executions
    eager_load = [Hyrax::Pageview, Hyrax::Download, Hyrax::WorkRelation, Hyrax::WorkUsage, Hyrax::FileUsage,
      Hyrax::WorkUsage::WorkViewStat, Hyrax::FileUsage::FileViewStat, MastersPaper]
    Rails.logger.debug("Eager loading classes: #{eager_load}")
    Tasks::StatsCacheUpdatingService.new.update_all
  end
end
