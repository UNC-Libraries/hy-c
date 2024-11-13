# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/services/hyrax/analytics/matomo.rb
Hyrax::Analytics::Matomo.module_eval do
  class_methods do
    # [hyc-override] added method for getting monthly stats by id
    # Pass in an action name and an id and get back the monthly count of events for that id. [date, event_count]
    def monthly_events_for_id(id, action, date = default_date_range)
      # Download events go to local database
      if action == 'file-set-in-work-download'
        start_date, end_date = split_date_range(date)
        return hyc_downloads_by_date_to_results(HycDownloadStat.with_work_id_and_date(id, start_date, end_date), start_date, end_date)
      elsif action == 'file-set-download'
        start_date, end_date = split_date_range(date)
        return hyc_downloads_by_date_to_results(HycDownloadStat.with_fileset_id_and_date(id, start_date, end_date), start_date, end_date)
      end

      additional_params = {
        flat: 1,
        label: "#{id} - #{action}"
      }
      response = api_params('Events.getName', 'month', date, additional_params)
      # Update keys by appending "-01" so that they can be parsed as dates
      response = response.transform_keys { |key| "#{key}-01" }
      results_array(response, 'nb_events')
    end

    # [hyc-override] added method for getting monthly stats
    def monthly_events(action, date = default_date_range)
      # Download events go to local database
      if action == 'file-set-download' || action == 'file-set-in-work-download'
        start_date, end_date = split_date_range(date)
        return hyc_downloads_by_date_to_results(HycDownloadStat.within_date_range(start_date, end_date), start_date, end_date)
      end

      additional_params = { label: action }
      response = api_params('Events.getAction', 'month', date, additional_params)
      # Update keys by appending "-01" so that they can be parsed as dates
      response = response.transform_keys { |key| "#{key}-01" }
      results_array(response, 'nb_events')
    end

    # [hyc-override] download events make use of the local database
    alias_method :original_top_events, :top_events
    def top_events(action, date = default_date_range)
      if action == 'file-set-in-work-download'
        start_date, end_date = split_date_range(date)
        return hyc_stats_by_field_to_results(HycDownloadStat.within_date_range(start_date, end_date), :work_id)
      elsif action == 'file-set-download'
        start_date, end_date = split_date_range(date)
        return hyc_downloads_by_field_to_results(HycDownloadStat.within_date_range(start_date, end_date), :fileset_id)
      end

      original_top_events(action, date)
    end

    def hyc_downloads_by_field_to_results(download_query, field)
      Hyrax::Analytics::Results.new(
        download_query
                    .group(field)
                    .select("#{field}, SUM(download_count) as download_count")
                    .map { |stat| [stat.send(field), stat.download_count] }
      )
    end

    def hyc_downloads_by_date_to_results(download_query, start_date, end_date)
      stats = download_query
                    .group(:date)
                    .select('date, SUM(download_count) as download_count')

      # Insert 0 values for any missing dates
      stats_hash = stats.to_h { |stat| [stat.date, stat.download_count] }
      full_stats = []
      current_date = start_date
      while current_date <= end_date do
        value = stats_hash.fetch(current_date, 0)
        full_stats << [current_date, value]
        current_date = current_date.next_month
      end

      Hyrax::Analytics::Results.new(full_stats)
    end

    def split_date_range(date_range)
      date_range.split(',').map { |date| Date.parse(date) }
    end
  end
end
