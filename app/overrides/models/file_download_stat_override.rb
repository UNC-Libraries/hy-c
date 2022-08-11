# https://github.com/samvera/hyrax/tree/v2.9.6/app/models/file_download_stat.rb
Hyrax::FileDownloadStat.class_eval do
  class << self
    # [hyc-override start]
    # Rename method so that we can wrap its behaviors with our additional old stats
    alias :original_ga_statistics :ga_statistics
    def ga_statistics(start_date, file)
      original_ga_statistics(start_date, as_subject(file))
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
    # [hyc-override end]
  end
end
