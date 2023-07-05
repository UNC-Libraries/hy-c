# frozen_string_literal: true
namespace 'hyc' do
  desc 'Update analytics statistics cache'
  task update_stats_cache: :environment do
    # Force legato model classes to eager load, since they add necessary methods to the legato profile
    Hyrax::Pageview
    Hyrax::Download
    Hyrax::WorkRelation
    Hyrax::WorkUsage
    Hyrax::FileUsage
    Hyrax::WorkUsage::WorkViewStat
    Tasks::StatsCacheUpdatingService.new.update_all
  end
end
