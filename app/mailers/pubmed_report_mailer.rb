# frozen_string_literal: true
class PubmedReportMailer < ApplicationMailer
  def pubmed_report_email(report)
    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end

  def truncated_pubmed_report_email(report, csv_paths)
    if csv_paths.nil? || !csv_paths.is_a?(Array) || csv_paths.empty?
      LogUtilsHelper.double_log('No CSV paths provided for attachment; sending email without attachments.', :warn, tag: 'truncated_pubmed_report_email')
    else
      LogUtilsHelper.double_log("Attaching CSV files: #{csv_paths.join(', ')})", :info, tag: 'truncated_pubmed_report_email')
      csv_paths.each do |path|
        attachments[File.basename(path)] = File.read(path)
      end
    end

    @report = report
    mail(to: 'cdr@unc.edu', subject: report[:subject])
  end
end
