# frozen_string_literal: true
class DimensionsReportMailer < ApplicationMailer
  def dimensions_report_email(report)
    @report = report
    mail(to: 'dcam@ad.unc.edu', subject: report[:subject])
  end
end
