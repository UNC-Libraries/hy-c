# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/models/file_download_stat.rb
Hyrax::FileDownloadStat.class_eval do
  class << self
    def ga_statistics(start_date, file)
      # [hyc-override] get subject as either the fileset or a wrapper to return both ids
      file = as_subject(file)
      profile = Hyrax::Analytics.profile
      unless profile
        Rails.logger.error('Google Analytics profile has not been established. Unable to fetch statistics.')
        return []
      end
      # [hyc-override] https://github.com/samvera/hyrax/issues/5955
      profile.hyrax__download(sort: 'date',
                              start_date: start_date,
                              end_date: Date.yesterday,
                              limit: 10_000)
             .for_file(file.id)
    end

    class StatsSubject
      attr_reader :id
      def initialize(id)
        @id = id
      end
    end

    # for objects with old ids, pass in an object which returns the old and the new id
    # so that we will get stats for both ids together.
    def as_subject(file)
      redirect_path = BoxcToHycRedirectService.redirect_lookup('new_path', file.id)
      if redirect_path
        subject = StatsSubject.new("#{file.id}|#{redirect_path['uuid']}")
      else
        file
      end
    end
  end
end
