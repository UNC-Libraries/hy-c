# frozen_string_literal: true
module NotificationUtilsHelper
  def self.suppress_emails
    return yield unless Rails.env.production?

    Thread.current[:suppress_hyrax_emails] = true
    Rails.logger.info "[NotificationUtilsHelper] Email suppression enabled for current thread"
    yield
  ensure
    Thread.current[:suppress_hyrax_emails] = false
    Rails.logger.info "[NotificationUtilsHelper] Email suppression disabled"
  end
end

