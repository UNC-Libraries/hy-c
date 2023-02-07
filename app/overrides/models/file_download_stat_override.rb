# frozen_string_literal: true
# https://github.com/samvera/hyrax/tree/v2.9.6/app/models/file_download_stat.rb
Hyrax::FileDownloadStat.class_eval do
  class << self
    # [hyc-override]
    # Rename method so that we can wrap its behaviors with our additional old stats
    # alias_method :original_ga_statistics, :ga_statistics

    # def ga_statistics(start_date, file)
    #   # This override assumes that ga_statistics only needs an object that returns an id
    #   original_ga_statistics(start_date, as_subject(file))
    # end

    def ga_statistics(start_date, file)
      file = as_subject(file)
      profile = Hyrax::Analytics.profile
      unless profile
        Rails.logger.error("Google Analytics profile has not been established. Unable to fetch statistics.")
        return []
      end
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
