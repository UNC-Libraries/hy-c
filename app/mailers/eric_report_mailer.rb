# frozen_string_literal: true
class ERICReportMailer < BaseIngestReportMailer
  def eric_report_email(report:, zip_path: nil)
    ingest_report_email(
      report: report,
      zip_path: zip_path,
      template_name: 'eric_report_email'
    )
  end
end
