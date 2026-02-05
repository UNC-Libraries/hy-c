# frozen_string_literal: true
class Tasks::NASAIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'NASA'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    report[:headers][:data_sources] = nasa_dir_count
    report[:headers][:admin_set_title] = @tracker['admin_set_title']
  end

  def nasa_dir_count
      # Count of NASA directories in the data directory
    data_dir = @config['data_dir']
    Dir.entries(data_dir).count { |entry| File.directory?(File.join(data_dir, entry)) && !(entry =='.' || entry == '..') }
  end

  def send_mail(report, zip_path)
    NASAReportMailer.report_email(report: report, zip_path: zip_path).deliver_now
  end
end
