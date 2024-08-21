# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_record_info(output_path, after_timestamp = nil)

      # Build the query
      query = FileDownloadStat.select(:id, :date, :downloads, :file_id)
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?

      # Fetch the IDs in batches
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

    def replicate_to_new_table(id_list_file, clean_index)
      # Read the list of IDs from the file and strip whitespace
      ids = File.readlines(id_list_file).map(&:strip)

      # Reindex the objects
      ids.each do |id|
        hyc_download_stat = HycDownloadStat.find_or_initialize_by(id)
      end
    end
  end
end
