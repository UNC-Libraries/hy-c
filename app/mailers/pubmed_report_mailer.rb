# frozen_string_literal: true
class PubmedReportMailer < ApplicationMailer
  def pubmed_report_email(report)
    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end
  end
