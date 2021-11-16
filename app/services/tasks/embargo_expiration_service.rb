module Tasks
  # @example How to call this service
  #  # Run today's embargoes
  #  Tasks::EmbargoExpirationService.run
  #  # Run yesterday's embargoes
  #  Tasks::EmbargoExpirationService.run(Time.zone.today - 1.day)
  class EmbargoExpirationService
    attr_reader :date, :work_types

    # Run the service. By default, it will check expirations against today.
    # You can also pass in a date.
    # @param [Date] date the date by which to measure expirations
    def self.run(date = nil)
      rundate =
        if date
          Date.parse(date)
        else
          Time.zone.today
        end
      Rails.logger.info "Running embargo expiration service for #{rundate}"
      EmbargoExpirationService.new(rundate).run
    end

    # Format a Date object such that it can be used in a solr query
    # @param [Date] date
    # @return [String] date formatted like "2017-07-27T00:00:00Z"
    def solrize_date(date)
      date.strftime('%Y-%m-%dT00:00:00Z')
    end

    def initialize(date)
      @date = date
      @work_types = [Article, Artwork, DataSet, Dissertation, General, HonorsThesis, Journal, MastersPaper, Multimed, ScholarlyWork]
    end

    def run
      expire_embargoes
    end

    def expire_embargoes
      expirations = find_expirations
      expirations.each do |expiration|
        Rails.logger.warn "Work #{expiration.id}: Expiring embargo"
        expiration.visibility = expiration.visibility_after_embargo if expiration.visibility_after_embargo
        expiration.deactivate_embargo!
        expiration.embargo.save
        expiration.save
        expiration.file_sets.each do |fs|
          fs.visibility = expiration.visibility
          fs.deactivate_embargo!
          fs.save
        end
      end
    end

    # Find all embargoes what will expire in the given number of days
    # @param [Integer] number of days
    def find_expirations
      expired_embargoes = []
      expiration_date = solrize_date(@date)

      @work_types.each do |work_type|
        expired_works = work_type.where("embargo_release_date_dtsi:[* TO #{RSolr.solr_escape(expiration_date)}]")
        expired_embargoes << expired_works
      end

      expired_embargoes.flatten
    end
  end
end
