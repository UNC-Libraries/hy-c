# https://github.com/samvera/hyrax/blob/v2.9.6/app/models/hyrax/statistic.rb
Hyrax::Statistic.class_eval do
  class << self
    include HycHelper

    # [hyc-override] add old id to filter query if work was migrated
    # Hyrax::Download is sent to Hyrax::Analytics.profile as #hyrax__download
    # see Legato::ProfileMethods.method_name_from_klass
    def ga_statistics(start_date, object)
      path = polymorphic_path(object)
      profile = Hyrax::Analytics.profile
      unless profile
        Rails.logger.error('Google Analytics profile has not been established. Unable to fetch statistics.')
        return []
      end

      # check if work was migrated
      redirect_path = redirect_lookup('new_path', path.split('/')[-1])

      path = "#{path}|/record/uuid:#{redirect_path['uuid']}" if redirect_path

      profile.hyrax__pageview(sort: 'date',
                              start_date: start_date,
                              end_date: Date.yesterday,
                              limit: 10_000).for_path(path)
    end

    private

    # [hyc-override] add error handling for timeouts
    def combined_stats(object, start_date, object_method, ga_key, user_id = nil)
      stat_cache_info = cached_stats(object, start_date, object_method)
      stats = stat_cache_info[:cached_stats]

      if stat_cache_info[:ga_start_date] < Time.zone.today
        begin
          ga_stats = ga_statistics(stat_cache_info[:ga_start_date], object)
          ga_stats.each do |stat|
            lstat = build_for(object, date: stat[:date], object_method: stat[ga_key], user_id: user_id)
            lstat.save unless Date.parse(stat[:date]) == Time.zone.today
            stats << lstat
          end
        rescue Net::ReadTimeout
          Rails.logger.warn "Unable to retrieve GA stats for #{object.id}. Request timed out. Using cached stats for object."
        end
      end

      stats
    end
  end
end
