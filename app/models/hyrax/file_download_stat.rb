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
      profile.hyrax__download(sort: 'date', start_date: start_date, end_date: Date.yesterday).for_file(redirect_id(file))
    end

    # this is called by the parent class
    # [hyc-override] include previous GA data
    def filter(file)
      { file_id: redirect_id(file.id) }
    end

    # [hyc-override]
    def redirect_id(file)
      filter_id = file.id

      # check if file was migrated
      redirect_path = redirect_lookup('new_path', filter_id)

      if redirect_path
        filter_id = "#{filter_id}|#{redirect_path['uuid']}"
      end

      filter_id
    end
  end
end
