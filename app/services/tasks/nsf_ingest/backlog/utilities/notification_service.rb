# frozen_string_literal: true
class Tasks::NSFIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'NSF'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    report[:headers][:total_files] = calculate_rows_in_csv(@config['file_info_csv_path'])
  end

  def send_mail(report, zip_path)
    NSFReportMailer.nsf_report_email(report: report, zip_path: zip_path).deliver_now
  end
end
