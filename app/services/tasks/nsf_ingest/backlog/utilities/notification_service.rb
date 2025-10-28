# frozen_string_literal: true
class Tasks::NSFIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'NSF'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    report[:headers][:total_files] = report[:headers][:total_files]
    all_dois = report[:records].values.flatten.map { |r| r[:doi] || r['doi'] }.compact.uniq
    report[:headers][:total_files] = all_dois.size
  end

  def send_mail(report, zip_path)
    NSFReportMailer.nsf_report_email(report: report, zip_path: zip_path).deliver_now
  end
end
