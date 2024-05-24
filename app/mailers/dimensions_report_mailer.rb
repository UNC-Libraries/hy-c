class DimensionsReportMailer < ApplicationMailer
  def dimensions_report_email(report)
    @report = report
    mail(to: 'recipient@example.com', subject: report[:subject])
  end
end
