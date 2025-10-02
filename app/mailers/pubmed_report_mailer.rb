# frozen_string_literal: true
class PubmedReportMailer < ApplicationMailer
  def pubmed_report_email(report)
    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end

  def truncated_pubmed_report_email(report, zip_path)
    if zip_path.blank? || !File.exist?(zip_path)
      LogUtilsHelper.double_log('No ZIP provided for attachment; sending email without attachments.', :warn, tag: 'truncated_pubmed_report_email')
    else
      attachments[File.basename(zip_path)] = File.read(zip_path)
      LogUtilsHelper.double_log("Attached ZIP file: #{zip_path}", :info, tag: 'truncated_pubmed_report_email')
    end

    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject], template_name: 'pubmed_report_email')
  end
end
