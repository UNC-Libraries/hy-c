# frozen_string_literal: true
class Tasks::NSFIngest::Backlog::Utilities::NotificationService < Tasks::BaseIngestNotificationService
  private

  def source_name
    'NSF'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    report[:headers][:total_files] = calculate_rows_in_csv(@config['file_info_csv_path'])
    report[:headers][:start_date] = Date.parse(@tracker['date_range']['start']).strftime('%Y-%m-%d')
    report[:headers][:end_date]   = Date.parse(@tracker['date_range']['end']).strftime('%Y-%m-%d')
  end

  def send_mail(report, zip_path)
    NSFReportMailer.nsf_report_email(report, zip_path).deliver_now
  end
end
