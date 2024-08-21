# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_record_info(output_path, after_timestamp = nil)

      # Build the query
      query = FileDownloadStat.select("file_id, DATE_TRUNC('month', date) AS date, SUM(downloads) AS downloads")
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?

      # Group by file_id and truncated month
      query = query.group("file_id, DATE_TRUNC('month', date)").order('file_id, month')

      # Fetch the IDs in batches for memory efficiency and performance
      records = []
      query.find_in_batches(batch_size: PAGE_SIZE) do |batch|
        records.concat(batch.map { |record| { id: record.id, date: record.date, downloads: record.downloads, file_id: record.file_id } })
      end

      # Write the records to the specified CSV file
      CSV.open(output_path, 'w', write_headers: true, headers: ['id', 'date', 'downloads', 'file_id']) do |csv|
        records.each do |record|
          csv << [record[:id], record[:date], record[:downloads], record[:file_id]]
        end
      end
    end

    def migrate_to_new_table(csv_path)
      csv_data = CSV.read(csv_path, headers: true)
      records = csv_data.map { |row| row.to_h.symbolize_keys }

      # Recreate or update objects in new table
      records.each do |stat|
        update_or_create_stat(stat)
      end
    end

    def update_or_create_stat(stat)
      hyc_download_stat = HycDownloadStat.find_or_initialize_by(id: stat.id.to_s)
      hyc_download_stat.assign_attributes(
        date: stat.date,
        downloads: stat.downloads,
        file_id: stat.file_id,
        user_id: stat.user_id
      )
      hyc_download_stat.save
    end
  end
end
