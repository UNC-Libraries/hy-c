# frozen_string_literal: true
desc 'Remove expired embargoes and send notifications. Pass date YYYY-MM-DD. Defaults to today.'
task :embargo_expiration, [:date] => [:environment] do |_t, args|
  Rails.logger.warn 'Running EmbargoExpirationService'
  Tasks::EmbargoExpirationService.run(args[:date])
end
