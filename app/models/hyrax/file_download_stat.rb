class FileDownloadStat < Hyrax::Statistic
  self.cache_column = :downloads
  self.event_type = :totalEvents

  class << self
    # Hyrax::Download is sent to Hyrax::Analytics.profile as #hyrax__download
    # see Legato::ProfileMethods.method_name_from_klass
    def ga_statistics(start_date, file)
      profile = Hyrax::Analytics.profile
      unless profile
        Rails.logger.error("Google Analytics profile has not been established. Unable to fetch statistics.")
        return []
      end
      profile.hyrax__download(sort: 'date',
                              start_date: start_date,
                              end_date: Date.yesterday)
          .for_file(file.id)
    end

    # this is called by the parent class
    # [hyc-override] include previous GA data
    def filter(file)
      filter_id = file.id

      # check if file was migrated
      if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
        redirect_uuids = File.read(ENV['REDIRECT_FILE_PATH'])
      else
        redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
      end

      csv = CSV.parse(redirect_uuids, headers: true)
      redirect_path = csv.find { |row| row['new_path'].match(file.id) }

      if redirect_path
        filter_id = [filter_id,"#{redirect_path['uuid']}"]
      end

      { file_id: redirect(Arrap.wrap(filter_id)) }
    end
  end
end
