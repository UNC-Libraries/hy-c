# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/stats_controller.rb
require 'hyrax/analytics/results'

Hyrax::StatsController.class_eval do
  def work
    # [hyc-override] different parameters and switched to using monthly instead of daily events
    @document = ::SolrDocument.find(params[:id])
    puts "initial: work_id=#{params[:id]}, start_date=#{start_date}, end_date=#{end_date}"
    # [hyc-override] Execute all of the stats requests in parallel
    threads = []
    threads << Thread.new do
      @pageviews = Hyrax::Analytics.monthly_events_for_id(@document.id, 'work-view', date = "#{start_date},#{end_date}")
    end
    # [hyc-override] Retrieve download stats from local database
    threads << Thread.new do
      begin
        @downloads = work_stats_as_results(@document.id)
      rescue StandardError => e
        Rails.logger.error("Error retrieving download stats: #{e}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
    threads.each(&:join)
  end

  def work_stats_as_results(work_id)
    # retrieve the download stats from the local database and turn it into a hash of date => nb_events
    stats = HycDownloadStat.with_work_id_and_date(work_id, start_date, end_date)
                  .group(:date)
                  .select('date, SUM(download_count) as download_count')
                  .map { |stat| [stat.date, stat.download_count] }

    # Insert 0 values for any missing dates
    stats_hash = stats.to_h
    full_stats = []
    current_date = start_date
    while current_date <= end_date do
      value = stats_hash.fetch(current_date, 0)
      full_stats << [current_date, value]
      current_date = current_date.next_month
    end

    Hyrax::Analytics::Results.new(full_stats)
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
end
