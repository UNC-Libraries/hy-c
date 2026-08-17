# frozen_string_literal: true
class PubmedReportMailer < BaseIngestReportMailer
  def pubmed_report_email(report: params[:report], zip_path: params[:zip_path])
    ingest_report_email(
      report: report,
      zip_path: zip_path,
      template_name: 'pubmed_report_email'
    )
  end
end
