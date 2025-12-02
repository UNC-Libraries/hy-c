# frozen_string_literal: true
class Tasks::ROSAPIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'ROSA-P'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    report[:headers][:total_files] = rosap_pdf_count
    report[:headers][:admin_set_title] = @tracker['admin_set_title']
  end

  def rosap_pdf_count
    # Count of ROSA-P PDFs in the full text directory
    full_text_dir = @config['full_text_dir']
    Dir.glob(File.join(full_text_dir, '**', '*.pdf')).count
  end

  def send_mail(report, zip_path)
    ROSAPReportMailer.report_email(report: report, zip_path: zip_path).deliver_now
  end
end
