# frozen_string_literal: true
namespace 'hyc' do
  desc 'Update analytics statistics cache'
  task update_stats_cache: :environment do
    Tasks::StatsCacheUpdatingService.new.update_all
  end
end
