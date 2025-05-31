# frozen_string_literal: true
class PubmedReportMailer < ApplicationMailer
  def pubmed_report_email(report)
    @report = report
    # WIP Change later
    mail(to: 'dcam@ad.unc.edu', subject: report[:subject])
  end
  end
