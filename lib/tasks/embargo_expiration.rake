desc "Remove expired embargoes and send notifications. Pass date YYYY-MM-DD. Defaults to today."
task :embargo_expiration, [:date] => [:environment] do |_t, args|
  Rails.logger.warn "Running EmbargoExpirationService"
  EmbargoExpirationService.run(args[:date])
end