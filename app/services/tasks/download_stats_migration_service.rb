# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_record_info(output_path, after_timestamp = nil)

      # Build the query
      query = FileDownloadStat.select("id, file_id, DATE_TRUNC('month', date) AS date, SUM(downloads) AS downloads")
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?

      # Group by file_id and truncated month
      query = query.group('id, file_id, date, downloads').order('file_id, date')

      # Fetch the IDs in batches for memory efficiency and performance
      records = []
      query.in_batches(of: PAGE_SIZE, load: true) do |relation|
        records.concat(relation.map { |record| { file_id: record.file_id, date: record.date, downloads: record.downloads } })
      end

      # Write the records to the specified CSV file
      CSV.open(output_path, 'w', write_headers: true, headers: ['file_id', 'date', 'downloads']) do |csv|
        records.each do |record|
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
      hyc_download_stat = HycDownloadStat.find_or_initialize_by(fileset_id: stat[:file_id].to_s)
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
  end
end
