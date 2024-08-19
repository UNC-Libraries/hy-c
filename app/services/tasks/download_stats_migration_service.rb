# frozen_string_literal: true
module Tasks
  class DownloadStatsMigrationService
    PAGE_SIZE = 1000
    def list_object_ids(output_path, after_timestamp = nil)
      # Build the query
      query = FileDownloadStat.select(:id)
      query = query.where('updated_at > ?', after_timestamp) if after_timestamp.present?

      # Fetch the IDs in batches
      ids = []
      query.find_in_batches(batch_size: PAGE_SIZE) do |batch|
        ids.concat(batch.map(&:id))
      end

      # Write the IDs to the specified output file
      File.open(output_path, 'w') do |file|
        ids.each { |id| file.puts(id) }
      end
    end
  end
end
