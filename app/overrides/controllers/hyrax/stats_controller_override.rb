# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/stats_controller.rb
require 'hyrax/analytics/results'

Hyrax::StatsController.class_eval do
  def work
    # [hyc-override] different parameters and switched to using monthly instead of daily events
    @document = ::SolrDocument.find(params[:id])
    # [hyc-override] Execute all of the stats requests in parallel
    threads = []
    threads << Thread.new do
      @pageviews = Hyrax::Analytics.monthly_events_for_id(@document.id, 'work-view')
    end
    # [hyc-override] Retrieve download stats from local database
    threads << Thread.new do
      @downloads = work_stats_as_results(@document.id)
    end
    threads.each(&:join)
  end

  def work_stats_as_results(work_id)
    # retrieve the download stats from the local database and turn it into a hash of date => nb_events
    Hyrax::Analytics::Results.new(
          HycDownloadStat.with_work_id_and_date(work_id, Hyrax.config.analytics_start_date, Time.zone.today)
                        .group(:date)
                        .select('date, SUM(download_count) as download_count')
                        .map { |stat| [stat.date, stat.download_count] })
  end

  def file
    # [hyc-override] file stats are not supported
    raise ActionController::RoutingError, 'Not Found'
  end
end
