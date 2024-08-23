# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_record_info(output_path, after_timestamp = nil)

    #   # Build the query
    #   query = FileDownloadStat.select("file_id, DATE_TRUNC('month', date) AS date, SUM(downloads) AS downloads")
    #   query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?

    #   # Group by file_id and truncated month
    #   query = query.group('file_id, DATE_TRUNC(\'month\', date)').order('file_id, date')
      query = FileDownloadStat.all
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?

    #   # Fetch the IDs in batches for memory efficiency and performance
    #   records = []
    #   query.in_batches(of: PAGE_SIZE, load: true) do |relation|
    #     records.concat(relation.map { |record| { file_id: record.file_id, date: record.date, downloads: record.downloads } })
    #   end

    # Fetch the records in batches to handle large datasets
      records = []
      query.find_each(batch_size: PAGE_SIZE) do |record|
        records << {
          file_id: record.file_id,
          date: record.date,
          downloads: record.downloads
        }
      end

    # Perform aggregation in Ruby
      aggregated_records = aggregate_downloads(records)

      # Write the records to the specified CSV file
      CSV.open(output_path, 'w', write_headers: true, headers: ['file_id', 'date', 'downloads']) do |csv|
        aggregated_records.each do |record|
          csv << [record[:file_id], record[:date], record[:downloads]]
        end
      end
    end

    def migrate_to_new_table(csv_path)
      csv_data = CSV.read(csv_path, headers: true)
      records = csv_data.map { |row| row.to_h.symbolize_keys }

      # Recreate or update objects in new table
      records.each do |stat|
        create_hyc_download_stat(stat)
      end
    end

    def create_hyc_download_stat(stat)
      puts "Inspect stat: #{stat.inspect}"
      puts "Stat file_id: #{stat[:file_id]}"
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

    def aggregate_downloads(records)
      aggregated_data = {}

      records.each do |record|
        file_id = record[:file_id]
        truncated_date = record[:date].beginning_of_month
        downloads = record[:downloads]

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
