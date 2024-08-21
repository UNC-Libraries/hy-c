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
        update_or_create_stat(stat)
      end
    end

    def update_or_create_stat(stat)
      puts "Inspect stat: #{stat.inspect}"
      puts "Stat file_id: #{stat[:file_id]}"
      hyc_download_stat = HycDownloadStat.find_or_initialize_by(fileset_id: stat[:file_id].to_s)
      hyc_download_stat.assign_attributes(
        date: stat[:date],
        download_count: stat[:downloads],
        fileset_id: stat[:file_id]
      )
      hyc_download_stat.save
    end
  end
end
