# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_work_stat_info(output_path, after_timestamp = nil)
      begin
        query = FileDownloadStat.all
        query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?
        total_work_stats = query.count
        timestamp_clause = after_timestamp.present? ? "after specified time #{after_timestamp}" : 'without a timestamp'

      # Log number of work stats retrieved and timestamp clause
        Rails.logger.info("Listing #{total_work_stats} work stats #{timestamp_clause} to #{output_path} from the hyrax local cache.")

        aggregated_data = {}
        work_stats_retrieved_from_query_count = 0

        Rails.logger.info('Retrieving work_stats from the database')
      # Fetch the work_stats and aggregate them into monthly stats in Ruby, encountered issues with SQL queries
        query.find_each(batch_size: PAGE_SIZE) do |stat|
          truncated_date = stat.date.beginning_of_month
          # Group the file_id and truncated date to be used as a key
          key = [stat.file_id, truncated_date]
          # Initialize the hash for the key if it doesn't exist
          aggregated_data[key] ||= { file_id: stat.file_id, date: truncated_date, downloads: 0 }
          # Sum the downloads for each key
          aggregated_data[key][:downloads] += stat.downloads
          work_stats_retrieved_from_query_count += 1
          log_progress(work_stats_retrieved_from_query_count, total_work_stats)
        end

        aggregated_work_stats = aggregated_data.values
        Rails.logger.info("Aggregated #{aggregated_work_stats.count} monthly stats from #{total_work_stats} daily stats")

        # Write the work_stats to the specified CSV file
        write_to_csv(output_path, aggregated_work_stats)
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
          work_id: work_data[:work_id],
          admin_set_id: work_data[:admin_set_id],
          work_type: work_data[:work_type],
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
