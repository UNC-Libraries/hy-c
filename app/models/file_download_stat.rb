# # TODO: See if this file is actually being used / picked up. Based on its location, and the fact that all tests pass
# when it is commented it, I suspect it may not be.
# [hyc-override] filter ga stats by old and new ids
class FileDownloadStat < Hyrax::Statistic
  self.cache_column = :downloads
  self.event_type = :totalEvents

  class << self
    include HycHelper
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
      redirect_path = redirect_lookup('new_path', file.id)

      filter_id = if redirect_path
                    "#{file.id}|#{redirect_path['uuid']}"
                  else
                    file.id
                  end

      profile.hyrax__download(sort: 'date',
                              start_date: start_date,
                              end_date: Date.yesterday,
                              limit: 10_000).for_file(filter_id)
    end

    # [hyc-override] add old id to filter query if work was migrated
    # this is called by the parent class
    def filter(file)
      redirect_path = redirect_lookup('new_path', file.id)

      _filter_id = if redirect_path
                    "#{file.id}|#{redirect_path['uuid']}"
                  else
                    file.id
                  end

      { file_id: file.id }
    end
  end
end
