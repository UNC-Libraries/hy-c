# frozen_string_literal: true
class Tasks::DTICIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'DTIC'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    all_filenames = report[:records].values.flatten.map { |r| r[:file_name] || r['file_name'] }.compact.uniq
    report[:headers][:total_files] = all_filenames.size
    report[:headers][:admin_set_title] = @tracker['admin_set_title']
  end

  def send_mail(report, zip_path)
    DTICReportMailer.dtic_report_email(report: report, zip_path: zip_path).deliver_now
  end
end
