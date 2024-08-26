# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_work_info(output_path, after_timestamp = nil)
      query = FileDownloadStat.all
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?
      total_works = query.count
      timestamp_clause = after_timestamp.present? ? "after specified time #{after_timestamp}" : 'without a timestamp'

     # Log number of works retrieved and timestamp clause
      Rails.logger.info("Listing works #{timestamp_clause} to #{output_path}")
      Rails.logger.info("#{total_works} works from the hyrax local cache.")

      works = []
      works_retrieved_from_query_count = 0

      Rails.logger.info("Retrieving works in batches of #{PAGE_SIZE}")
     # Fetch the works in batches
      query.find_each(batch_size: PAGE_SIZE) do |work|
        works << {
          file_id: work.file_id,
          date: work.date,
          downloads: work.downloads
        }
        works_retrieved_from_query_count += 1
        log_progress(works_retrieved_from_query_count, total_works)
      end

     # Perform aggregation of daily stats ino monthly stats in Ruby, encountered issues with SQL queries
      aggregated_works = aggregate_downloads(works)

      # Write the works to the specified CSV file
      CSV.open(output_path, 'w', write_headers: true, headers: ['file_id', 'date', 'downloads']) do |csv|
        aggregated_works.each do |work|
          csv << [work[:file_id], work[:date], work[:downloads]]
        end
      end
    end

    def migrate_to_new_table(csv_path)
      csv_data = CSV.read(csv_path, headers: true)
      works = csv_data.map { |row| row.to_h.symbolize_keys }

      # Recreate or update objects in new table
      works.each do |stat|
        create_hyc_download_stat(stat)
      end
    end

    # Log progress at 25%, 50%, 75%, and 100%
    def log_progress(works_retrieved_from_query_count, total_works, is_aggregation = false)
        percentages = [0.25, 0.5, 0.75, 1.0]
        log_intervals = percentages.map { |percent| (total_works * percent).to_i }    
        if log_intervals.include?(works_retrieved_from_query_count)
          percentage_done = percentages[log_intervals.index(works_retrieved_from_query_count)] * 100
          process_type = is_aggregation ? 'Aggregation' : 'Retrieval'
          Rails.logger.info("#{process_type} progress: #{percentage_done}% (#{works_retrieved_from_query_count}/#{total_works} works)")
        end
    end

    def create_hyc_download_stat(stat)
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
      hyc_download_stat.save
    end

    # Similar implementation to work_data in DownloadAnalyticsBehavior
    # Memoization is not necessary here since this method is called per stat
    def work_data_from_stat(stat)
      WorkUtilsHelper.fetch_work_data_by_fileset_id(stat[:file_id])
    end

    def aggregate_downloads(works)
      aggregated_data = {}

      works.each do |work|
        file_id = work[:file_id]
        truncated_date = work[:date].beginning_of_month
        downloads = work[:downloads]

        # Group the file_id and truncated date to be used as a key
        key = [file_id, truncated_date]
        # Initialize the hash for the key if it doesn't exist
        aggregated_data[key] ||= { file_id: file_id, date: truncated_date, downloads: 0 }
        # Sum the downloads for each key
        aggregated_data[key][:downloads] += downloads
      end
      aggregated_data.values
    end
  end
end
