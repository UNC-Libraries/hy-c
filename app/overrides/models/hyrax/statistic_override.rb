# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v2.9.6/app/models/hyrax/statistic.rb
Hyrax::Statistic.class_eval do
  class << self
    # [hyc-override]
    # Flag indicating if ReadTimeouts should be raised or suppressed
    def raise_timeouts?
      @@raise_timeouts ||= ENV['ANALYTICS_RAISE_TIMEOUTS'].to_s.downcase == 'true'
    end

    def raise_timeouts=(value)
      @@raise_timeouts = value
    end

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
      redirect_path = BoxcToHycRedirectService.redirect_lookup('new_path', path.split('/')[-1])

      path = "#{path}|/record/uuid:#{redirect_path['uuid']}" if redirect_path

      # [hyc-override] https://github.com/samvera/hyrax/issues/5955
      profile.hyrax__pageview(sort: 'date',
                              start_date: start_date,
                              end_date: Date.yesterday,
                              limit: 10_000)
             .for_path(path)
    end

    private

    # [hyc-override] add error handling for timeouts
    alias_method :original_combined_stats, :combined_stats

    def combined_stats(object, start_date, object_method, ga_key, user_id = nil)
      begin
        original_combined_stats(object, start_date, object_method, ga_key, user_id)
      rescue Net::ReadTimeout => e
        # Optionally suppress or raise any ReadTimeout errors
        if Hyrax::Statistic::raise_timeouts?
          raise e
        else
          Rails.logger.warn "Unable to retrieve GA stats for #{object.id}. Request timed out. Using cached stats for object."
          # return the cached statistics since we can't get fresh ones
          stat_cache_info = cached_stats(object, start_date, object_method)
          stats = stat_cache_info[:cached_stats]
        end
      end
    end
  end
end
