# app/controllers/emails_controller.rb
class EmailsController < ApplicationController
    def send_test_email
      begin
        DimensionsReportMailer.test_email.deliver_now
        render plain: "Test email sent."
      rescue StandardError => e
        Rails.logger.error "Failed to send test email: #{e.message}"
        render plain: "Failed to send test email.", status: :internal_server_error
      end
    end
  end
  