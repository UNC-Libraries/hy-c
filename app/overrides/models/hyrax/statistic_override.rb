# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/models/hyrax/statistic.rb
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
