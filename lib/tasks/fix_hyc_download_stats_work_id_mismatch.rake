# frozen_string_literal: true
desc 'Fix hyc_download_stats work_id mismatch'
task fix_hyc_download_stats_work_id_mismatch: :environment do
  puts 'Starting to fix hyc_download_stats work_id mismatches...'
    # Retrieve where work_id is equal to fileset_id
  download_stats = HycDownloadStat.where('work_id = fileset_id')
  updated = 0
  download_stats.each do |download_stat|
      # Retrieve the work data for the fileset id
    work_data = WorkUtilsHelper.fetch_work_data_by_fileset_id(download_stat.fileset_id)

    begin
      # Update the download stat with the work id
        download_stat.update!(work_id: work_data[:work_id] || 'Unknown')
        updated += 1
    rescue StandardError => e
        # Log any errors encountered during the update
      puts "Failed to update HycDownloadStat ID #{download_stat.id}: #{e.message}"
      end
  end
  puts 'Completed fixing hyc_download_stats work_id mismatches.'
  puts "Successfully updated #{updated} records out of #{download_stats.count} attempted."
end
