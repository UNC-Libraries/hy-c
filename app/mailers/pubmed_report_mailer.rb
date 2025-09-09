# frozen_string_literal: true
class PubmedReportMailer < ApplicationMailer
  def pubmed_report_email(report)
    @report = report
    # WIP -- change to actual admin email later
    mail(to: 'dcam@unc.edu', subject: report[:subject])
  end
  end
