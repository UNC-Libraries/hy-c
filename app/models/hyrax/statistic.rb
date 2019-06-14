module Hyrax
  class Statistic < ActiveRecord::Base
    self.abstract_class = true

    class_attribute :cache_column, :event_type

    class << self
      include ActionDispatch::Routing::PolymorphicRoutes
      include Rails.application.routes.url_helpers

      def statistics_for(object)
        where(filter(object))
      end

      def build_for(object, attrs)
        new attrs.merge(filter(object))
      end

      def convert_date(date_time)
        date_time.to_datetime.to_i * 1000
      end

      def statistics(object, start_date, user_id = nil)
        combined_stats object, start_date, cache_column, event_type, user_id
      end

      # Hyrax::Download is sent to Hyrax::Analytics.profile as #hyrax__download
      # see Legato::ProfileMethods.method_name_from_klass
      # [hyc-override] include previous GA data
      def ga_statistics(start_date, object)
        path = polymorphic_path(object)
        profile = Hyrax::Analytics.profile
        unless profile
          Rails.logger.error("Google Analytics profile has not been established. Unable to fetch statistics.")
          return []
        end
        profile.hyrax__pageview(sort: 'date', start_date: start_date).for_path(redirect(path))
      end

      private

      def cached_stats(object, start_date, _method)
        stats = statistics_for(object).order(date: :asc)
        ga_start_date = stats.any? ? stats[stats.size - 1].date + 1.day : start_date.to_date
        { ga_start_date: ga_start_date, cached_stats: stats.to_a }
      end

      def combined_stats(object, start_date, object_method, ga_key, user_id = nil)
        stat_cache_info = cached_stats(object, start_date, object_method)
        stats = stat_cache_info[:cached_stats]
        if stat_cache_info[:ga_start_date] < Time.zone.today
          ga_stats = ga_statistics(stat_cache_info[:ga_start_date], object)
          ga_stats.each do |stat|
            lstat = build_for(object, date: stat[:date], object_method => stat[ga_key], user_id: user_id)
            lstat.save unless Date.parse(stat[:date]) == Time.zone.today
            stats << lstat
          end
        end
        stats
      end
    end

    def to_flot
      [self.class.convert_date(date), send(cache_column)]
    end

    def redirect(path)
      if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
        redirect_uuids = File.read(ENV['REDIRECT_FILE_PATH'])
      else
        redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
      end

      csv = CSV.parse(redirect_uuids, headers: true)
      redirect_path = csv.find { |row| row['new_path'].match(path) }

      if redirect_path
        "#{path}|/record/uuid:#{redirect_path['uuid']}"
      else
        path
      end
    end
  end
end
