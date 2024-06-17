# frozen_string_literal: true
class DimensionsReportMailer < ApplicationMailer
  def dimensions_report_email(report)
    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end
end
