class EmailSuppressionInterceptor
  def self.delivering_email(message)
    if Thread.current[:suppress_hyrax_emails]
      Rails.logger.info "[EmailSuppressionInterceptor] Suppressed email: #{message.subject}"
      message.perform_deliveries = false
    end
  end
end

ActionMailer::Base.register_interceptor(EmailSuppressionInterceptor)