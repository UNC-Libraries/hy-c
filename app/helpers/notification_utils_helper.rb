# frozen_string_literal: true
module NotificationUtilsHelper
  def self.suppress_emails
    return yield unless Rails.env.production? # Only suppress in production

    prev = Rails.application.config.action_mailer.perform_deliveries
    LogUtilsHelper.double_log("Suppressing emails: #{prev} -> false", :info, tag: 'suppress_emails')
    Rails.application.config.action_mailer.perform_deliveries = false

    begin
      yield
    ensure
      # Always restore the previous setting, even if an exception occurs
      Rails.application.config.action_mailer.perform_deliveries = prev
      LogUtilsHelper.double_log("Restored email delivery setting to: #{prev}", :info, tag: 'suppress_emails')
    end
  end
end
