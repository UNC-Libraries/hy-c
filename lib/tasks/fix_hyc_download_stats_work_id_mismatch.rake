# frozen_string_literal: true
desc 'Fix hyc_download_stats work_id mismatch'
task :fix_hyc_download_stats_work_id_mismatch do
    # Retrieve where work_id is equal to fileset_id
  download_stats = HycDownloadStat.where('work_id = fileset_id')
  download_stats.each do |download_stat|
      # Retrieve the work data for the fileset id
    work_data = WorkUtilsHelper.fetch_work_data_by_fileset_id(download_stat.fileset_id)
      # Update the download stat with the work id
    download_stat.update(work_id: work_data[:work_id])
  end
end
