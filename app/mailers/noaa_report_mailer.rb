# frozen_string_literal: true
class NoaaReportMailer < BaseIngestReportMailer
  def report_email(report: params[:report], zip_path: params[:zip_path])
    ingest_report_email(
      report: report,
      zip_path: zip_path,
      template_name: 'report_email'
    )
  end
end
