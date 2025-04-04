# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/stats_controller.rb
require 'hyrax/analytics/results'

Hyrax::StatsController.class_eval do
  def self.turnstile_enabled?
    @turnstile_enabled ||= ENV.fetch('CF_TURNSTILE_ENABLED', 'false').downcase == 'true'
  end
  before_action { |controller| BotDetectController.bot_detection_enforce_filter(controller) if self.class.turnstile_enabled? }

  def work
    # [hyc-override] different parameters and switched to using monthly instead of daily events
    @document = ::SolrDocument.find(params[:id])
    # [hyc-override] Execute all of the stats requests in parallel
    threads = []
    threads << Thread.new do
      @pageviews = Hyrax::Analytics.monthly_events_for_id(@document.id, 'work-view', date = date_range)
    end
    # [hyc-override] Retrieve download stats from local database
    threads << Thread.new do
      @downloads = Hyrax::Analytics.monthly_events_for_id(@document.id, 'file-set-in-work-download', date = date_range)
    end
    threads.each(&:join)
  end

  def file
    # [hyc-override] file stats are not supported
    raise ActionController::RoutingError, 'Not Found'
  end

  def end_date
    @end_date ||= Time.zone.today.beginning_of_month
  end

  def start_date
    @start_date ||= (end_date - 11.months).beginning_of_month
  end

  def date_range
    "#{start_date},#{end_date}"
  end
end
