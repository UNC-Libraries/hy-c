# frozen_string_literal: true
class PubmedReportMailer < ApplicationMailer
  def pubmed_report_email(report)
    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end

  def truncated_pubmed_report_email(report, csv_paths)
    csv_paths.each do |path|
      attachments[File.basename(path)] = File.read(path)
    end

    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end
end
