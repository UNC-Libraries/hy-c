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

    # [hyc-override] Returning cached stats temporarily until GA4 implementation is complete
    def combined_stats(object, start_date, object_method, ga_key, user_id = nil)
      stat_cache_info = cached_stats(object, start_date, object_method)
      stat_cache_info[:cached_stats]
    end
  end
end
