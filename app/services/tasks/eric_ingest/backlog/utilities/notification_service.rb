# frozen_string_literal: true
class Tasks::EricIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'ERIC'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    report[:headers][:total_files] = eric_pdf_count
  end

  def eric_pdf_count
    # Count of ERIC PDFs in the full text directory
    full_text_dir = @config['full_text_dir']
    Dir.glob(File.join(full_text_dir, '**', '*.pdf')).count
  end

  def send_mail(report, zip_path)
    ERICReportMailer.eric_report_email(report: report, zip_path: zip_path).deliver_now
  end
end
