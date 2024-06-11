# frozen_string_literal: true
class DimensionsReportMailer < ApplicationMailer
  def dimensions_report_email(report)
    @report = report
    mail(to: 'dcsoups@gmail.com', subject: report[:subject])
  end

  def test_email
    mail(to: 'dcsoups@gmail.com', subject: 'Test Email', body: 'This is a test email.')
  end
end
