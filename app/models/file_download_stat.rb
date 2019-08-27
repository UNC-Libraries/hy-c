# [hyc-override] filter ga stats by old and new ids
class FileDownloadStat < Hyrax::Statistic
  self.cache_column = :downloads
  self.event_type = :totalEvents

  class << self
    include HyraxHelper
    # Hyrax::Download is sent to Hyrax::Analytics.profile as #hyrax__download
    # see Legato::ProfileMethods.method_name_from_klass
    def ga_statistics(start_date, file)
      profile = Hyrax::Analytics.profile
      unless profile
        Rails.logger.error("Google Analytics profile has not been established. Unable to fetch statistics.")
        return []
      end

      # [hyc-override] add old id to filter query if work was migrated
      # check if file was migrated
      filter_id = file.id

      redirect_path = redirect_lookup('new_path', filter_id)

      if redirect_path
        filter_id = "#{filter_id}|#{redirect_path['uuid']}"
      end

      profile.hyrax__download(sort: 'date',
                              start_date: start_date,
                              end_date: Date.yesterday,
                              limit: 10000).for_file(filter_id)
    end

    # [hyc-override] add old id to filter query if work was migrated
    # this is called by the parent class
    def filter(file)
      filter_id = file.id

      # check if file was migrated
      redirect_path = redirect_lookup('new_path', filter_id)

      if redirect_path
        filter_id = "#{filter_id}|#{redirect_path['uuid']}"
      end

      { file_id: file.id }
    end
  end
end
