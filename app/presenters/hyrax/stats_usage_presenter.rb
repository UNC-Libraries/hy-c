# [hyc-override] use date_created instead of date_updated for analytics start date
module Hyrax
  # Methods used by both WorkUsage and FileUsage
  class StatsUsagePresenter
    attr_accessor :id, :model

    def created
      @created ||= date_for_analytics
    end

    private

    def user_id
      @user_id ||= begin
        user = Hydra::Ability.user_class.find_by_user_key(model.depositor)
        user ? user.id : nil
      end
    end

    # TODO: make this a lazy enumerator
    def to_flots(stats)
      stats.map(&:to_flot)
    end

    # model.date_uploaded reflects the date the object was uploaded by the user
    # and therefore (if available) the date that we want to use for the stats
    # model.create_date reflects the date the file was added to Fedora. On data
    # migrated from one repository to another the created_date can be later
    # than the date the file was uploaded.
    #
    # switch to using date_created as primary date and the system create date as backup
    # all migrated works will have a date_created value
    def date_for_analytics
      earliest = Hyrax.config.analytic_start_date
      date_created = string_to_date(model.date_created.to_s)
      date_analytics = date_created ? date_created : string_to_date(model.create_date.to_s)
      return date_analytics if earliest.blank?
      earliest > date_analytics ? earliest : date_analytics
    end

    def string_to_date(date_str)
      DateTime.parse(date_str)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
