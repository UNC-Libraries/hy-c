class DimensionsReportMailer < ApplicationMailer
  def report_email(report)
    @report = report
    mail(to: 'recipient@example.com', subject: report[:subject])
  end
end
