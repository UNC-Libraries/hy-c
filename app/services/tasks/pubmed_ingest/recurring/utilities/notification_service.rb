# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService
  private

  def source_name
    'PubMed'
  end

  def populate_headers!(report)
    report[:headers][:depositor] = @tracker['depositor_onyen']
    all_pmids = report[:records].values.flatten.map { |r| r[:pmid] || r['pmid'] }.compact.uniq
    report[:headers][:total_unique_records] = all_pmids.size
    report[:headers][:start_date] = Date.parse(@tracker['date_range']['start']).strftime('%Y-%m-%d')
    report[:headers][:end_date]   = Date.parse(@tracker['date_range']['end']).strftime('%Y-%m-%d')
  end

  def send_mail(report, zip_path)
    PubmedReportMailer.pubmed_report_email(report: report, zip_path: zip_path).deliver_now
  end
end
