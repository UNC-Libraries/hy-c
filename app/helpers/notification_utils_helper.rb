# frozen_string_literal: true
module NotificationUtilsHelper
  def self.suppress_emails
    return yield unless Rails.env.production? # Only suppress in production

    prev = Rails.application.config.action_mailer.perform_deliveries
    Rails.application.config.action_mailer.perform_deliveries = false
    yield
  ensure
    Rails.application.config.action_mailer.perform_deliveries = prev
  end
end
