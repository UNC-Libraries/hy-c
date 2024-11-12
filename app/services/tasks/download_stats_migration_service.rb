# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    module DownloadMigrationSource
      MATOMO = :matomo
      GA4 = :ga4
      CACHE = :cache

      def self.all_sources
        [MATOMO, GA4, CACHE]
      end

      def self.valid?(source)
        all_sources.include?(source)
      end
    end
    def list_work_stat_info(output_path, source, after_timestamp = nil, before_timestamp = nil, ga_stats_dir = nil)
      aggregated_work_stats = []
      begin
        case source
        when DownloadMigrationSource::CACHE
          aggregated_work_stats = fetch_local_cache_stats(after_timestamp)
          write_to_csv(output_path, aggregated_work_stats)
        when DownloadMigrationSource::MATOMO
          aggregated_work_stats = fetch_matomo_stats(after_timestamp, before_timestamp)
          write_to_csv(output_path, aggregated_work_stats)
        when DownloadMigrationSource::GA4
          aggregated_work_stats = fetch_ga4_stats(ga_stats_dir)
          write_to_csv(output_path, aggregated_work_stats)
        else
          raise ArgumentError, "Unsupported source: #{source}"
        end
      rescue StandardError => e
        Rails.logger.error("An error occurred while listing work stats: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end

    def migrate_to_new_table(csv_path)
      begin
        csv_data = CSV.read(csv_path, headers: true)
        csv_data_stats = csv_data.map { |row| row.to_h.symbolize_keys }
        progress_tracker = {
          all_categories: 0,
          created: 0,
          updated: 0,
          skipped: 0,
          failed: 0
        }

        Rails.logger.info("Migrating #{csv_data_stats.count} work stats to the new table.")
        # Recreate or update objects in new table
        csv_data_stats.each do |stat|
          create_hyc_download_stat(stat, progress_tracker)
          progress_tracker[:all_categories] += 1
          log_progress(progress_tracker[:all_categories], csv_data_stats.count, 'Migration')
        end
        Rails.logger.info("Migration complete: #{progress_tracker[:created]} created, #{progress_tracker[:updated]} updated, #{progress_tracker[:skipped]} skipped, #{progress_tracker[:failed]} failed")
      rescue StandardError => e
        Rails.logger.error("An error occurred while migrating work stats: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end

    private

    def fetch_ga4_stats(ga_stats_dir)
      aggregated_data = {}
      total_unique_row_count = 0
      Rails.logger.info("Fetching GA4 work stats from specified path #{ga_stats_dir}.")

      # Iterate through each CSV file in the specified directory
      Dir.glob(File.join(ga_stats_dir, '*.csv')).each do |file_path|
        range_start_date = retrieve_start_date_from_csv(file_path)
        unique_row_count = 0
        Rails.logger.info("Processing file with start date: #{range_start_date}")
        # Read each CSV file and aggregate data
        CSV.foreach(file_path, headers: true).with_index do |row, index|
          # Skip the first 3 rows containing metadata and column names
          next if index < 3
          # Fetch values based on the column names 'Custom parameter' and 'Event count'
          fileset_id = row[0]
          download_count = row[1].to_i
          # Range start date is always the first of the month, no need for truncation
          update_aggregate_stats(aggregated_data, range_start_date, fileset_id, download_count)
          unique_row_count += 1
        end
        total_unique_row_count += unique_row_count
        Rails.logger.info("Processed #{unique_row_count} daily stats. Aggregated data contains #{aggregated_data.values.count} entries.")
      end
      Rails.logger.info("Aggregated #{aggregated_data.values.count} monthly stats from #{total_unique_row_count} daily stats")
      aggregated_data.values
    end

    # Method to fetch and aggregate work stats from Matomo
    def fetch_matomo_stats(after_timestamp, before_timestamp)
      aggregated_data = {}
      # Keeps count of stats retrieved from Matomo from all queries
      all_query_stat_total = 0
      # Log number of work stats retrieved and timestamp clause
      timestamp_clause = "in specified range #{after_timestamp} to #{before_timestamp}"
      Rails.logger.info("Fetching work stats #{timestamp_clause} from Matomo.")

      # Query Matomo API for each month in the range and aggregate the data
      # Setting period to month will return stats for each month in the range, regardless of the specified date
      reporting_uri = URI("#{ENV['MATOMO_BASE_URL']}/index.php")
      # Fetch the first of each month in the range
      months_array = first_of_each_month_in_range(after_timestamp, before_timestamp)
      months_array.each_with_index do |first_date_of_month, index|
        uri_params = {
          module: 'API',
          idSite: ENV['MATOMO_SITE_ID'],
          method: 'Events.getName',
          period: 'month',
          date: first_date_of_month,
          format: JSON,
          token_auth: ENV['MATOMO_AUTH_TOKEN'],
          flat: '1',
          filter_pattern: 'DownloadIR',
          filter_limit: -1,
          showColumns: 'nb_events',
        }
        reporting_uri.query = URI.encode_www_form(uri_params)
        response = HTTParty.get(reporting_uri.to_s)
        month_year_string = first_date_of_month.to_date.strftime('%B %Y')
        Rails.logger.info("Processing Matomo response for #{month_year_string}. (#{index + 1}/#{months_array.count})")
        response.parsed_response.each do |stat|
          # Events_EventName is the file_id, nb_events is the number of downloads
          update_aggregate_stats(aggregated_data, first_date_of_month, stat['Events_EventName'], stat['nb_events'])
        end
        monthly_stat_total = response.parsed_response.length
        all_query_stat_total += monthly_stat_total
      end
      Rails.logger.info("Aggregated #{aggregated_data.values.count} monthly stats from #{all_query_stat_total} total retrieved stats")
      # Return the aggregated data
      aggregated_data.values
    end

    def update_aggregate_stats(aggregated_data, truncated_date, file_id, downloads)
      # Group the file_id and truncated date to be used as a key
      key = [file_id, truncated_date]
      # Initialize the hash for the key if it doesn't exist
      aggregated_data[key] ||= { file_id: file_id, date: truncated_date, downloads: 0 }
      # Sum the downloads for each key
      aggregated_data[key][:downloads] += downloads
    end

    def first_of_each_month_in_range(after_timestamp, before_timestamp)
      after_date = after_timestamp.to_date.beginning_of_month
      before_date = before_timestamp.to_date.beginning_of_month
      (after_date..before_date).select { |d| d.day == 1 }.map(&:to_s)
    end

    # Method to fetch and aggregate work stats from the local cache
    def fetch_local_cache_stats(after_timestamp)
      aggregated_data = {}
      work_stats_retrieved_from_query_count = 0
      query = FileDownloadStat.all
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?
      total_work_stats = query.count
      timestamp_clause = after_timestamp.present? ? "after specified time #{after_timestamp}" : 'without a timestamp'

    # Log number of work stats retrieved and timestamp clause
      Rails.logger.info("Fetching #{total_work_stats} work stats #{timestamp_clause} from the hyrax local cache.")

    # Fetch the work_stats and aggregate them into monthly stats in Ruby, encountered issues with SQL queries
      query.find_each(batch_size: PAGE_SIZE) do |stat|
        update_aggregate_stats(aggregated_data, stat.date.beginning_of_month, stat.file_id, stat.downloads)
        work_stats_retrieved_from_query_count += 1
        log_progress(work_stats_retrieved_from_query_count, total_work_stats)
      end

      Rails.logger.info("Aggregated #{aggregated_data.values.count} monthly stats from #{total_work_stats} daily stats")
      # Return the aggregated data
      aggregated_data.values
    end

    # Assuming the second line of the CSV file contains the start date, process it and return the date
    # Example: # Start date: 20220101
    def retrieve_start_date_from_csv(file_path)
      File.open(file_path) do |file|
        # Skip the first line
        file.readline

        # Read and process the second line
        second_line = file.readline.strip
        if second_line.start_with?('# Start date:')
          date_str = second_line.split(':').last.strip
          begin
            start_date = DateTime.strptime(date_str, '%Y%m%d')
            return start_date.strftime('%Y-%m-%d')  # Format to 'YYYY-MM-DD'
          rescue ArgumentError
            raise ArgumentError, "Invalid date format '#{date_str}' in file #{file_path}"
          end
        else
          raise ArgumentError, "Error reading start date from #{file_path}. '#{second_line}' does not adhere to the expected format."
          return nil
        end
      end
    end

    # Log progress at 25%, 50%, 75%, and 100%
    def log_progress(work_stats_count, total_work_stats, process_type = 'Retrieval and Aggregation')
      percentages = [0.25, 0.5, 0.75, 1.0]
      log_intervals = percentages.map { |percent| (total_work_stats * percent).to_i }
      if log_intervals.include?(work_stats_count)
        percentage_done = percentages[log_intervals.index(work_stats_count)] * 100
        Rails.logger.info("#{process_type} progress: #{percentage_done}% (#{work_stats_count}/#{total_work_stats} work_stats)")
      end
    end

    def create_hyc_download_stat(stat, progress_tracker)
      begin
        hyc_download_stat = HycDownloadStat.find_or_initialize_by(
          fileset_id: stat[:file_id].to_s,
          date: stat[:date]
      )
        work_data = work_data_from_stat(stat)
        hyc_download_stat.assign_attributes(
          fileset_id: stat[:file_id],
          work_id: work_data[:work_id]  || 'Unknown',
          admin_set_id: work_data[:admin_set_id]  || 'Unknown',
          work_type: work_data[:work_type]  || 'Unknown',
          date: stat[:date],
          download_count: stat[:downloads],
        )
      rescue StandardError => e
        Rails.logger.error("Failed to create HycDownloadStat for #{stat.inspect}: #{e.message}")
        progress_tracker[:failed] += 1
      end
      save_hyc_download_stat(hyc_download_stat, stat, progress_tracker)
    end

    # Similar implementation to work_data in DownloadAnalyticsBehavior
    # Memoization is not necessary here since this method is called per stat
    def work_data_from_stat(stat)
      WorkUtilsHelper.fetch_work_data_by_fileset_id(stat[:file_id])
    end

    # Method to write work stats to a CSV file
    def write_to_csv(output_path, work_stats, headers = ['file_id', 'date', 'downloads'])
      CSV.open(output_path, 'w', write_headers: true, headers: headers) do |csv|
        work_stats.each do |stat|
          csv << [stat[:file_id], stat[:date], stat[:downloads]]
        end
      end
      Rails.logger.info("Work stats successfully written to #{output_path}")
    end

    # Method to save the HycDownloadStat object and update the progress tracker
    def save_hyc_download_stat(hyc_download_stat, stat, progress_tracker)
      begin
        if hyc_download_stat.new_record?
          hyc_download_stat.save
          progress_tracker[:created] += 1
        elsif hyc_download_stat.changed?
          hyc_download_stat.save
          progress_tracker[:updated] += 1
        else
          progress_tracker[:skipped] += 1
        end
      rescue StandardError => e
        Rails.logger.error("Error saving new row to HycDownloadStat: #{stat.inspect}: #{e.message}")
        progress_tracker[:failed] += 1
      end
    end

  end
end
