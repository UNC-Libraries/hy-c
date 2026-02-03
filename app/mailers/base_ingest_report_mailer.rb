# frozen_string_literal: true
class BaseIngestReportMailer < ApplicationMailer
  def ingest_report_email(report:, zip_path:, template_name:)
    if zip_path.blank? || !File.exist?(zip_path)
      LogUtilsHelper.double_log(
        'No ZIP provided for attachment; sending email without attachments.',
        :warn,
        tag: "#{template_name}_report_email"
      )
    else
      attachments[File.basename(zip_path)] = File.read(zip_path)
      LogUtilsHelper.double_log(
        "Attached ZIP file: #{zip_path}",
        :info,
        tag: "#{template_name}_report_email"
      )
    end

    @report = report
    mail(
      to: report[:to] || 'cdr@unc.edu',
      subject: report[:subject],
      template_name: template_name
    )
  end
end
