# frozen_string_literal: true
class RosapReportMailer < BaseIngestReportMailer
  def report_email(report:, zip_path: nil)
    ingest_report_email(
      report: report,
      zip_path: zip_path,
      template_name: 'report_email'
    )
  end
end
