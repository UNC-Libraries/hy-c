# frozen_string_literal: true
module Tasks::IngestHelperUtils::NotificationHelper
  extend self

  def send_report_and_notify(results:, tracker:, csv_output_dir:, mailer:)
    return if tracker.dig('progress', 'send_summary_email', 'completed')

    LogUtilsHelper.double_log('Finalizing report and sending notification email...', :info, tag: 'send_summary_email')

    begin
      csv_paths = Tasks::Shared::ReportingService.generate_result_csvs(results: results, csv_output_dir: csv_output_dir)
      zip_path  = Tasks::Shared::ReportingService.compress_result_csvs(csv_paths: csv_paths, csv_output_dir: csv_output_dir)

      report = build_report(results: results, tracker: tracker)
      mailer.pubmed_report_email(report: report, zip_path: zip_path).deliver_now

      tracker['progress']['send_summary_email']['completed'] = true
      tracker.save
      LogUtilsHelper.double_log('Email notification sent successfully.', :info, tag: 'send_summary_email')
    rescue StandardError => e
      LogUtilsHelper.double_log("Failed to send email notification: #{e.message}", :error, tag: 'send_summary_email')
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
    end
  end

  def build_report(results:, tracker:)
    {
      headers: {
        depositor: tracker['depositor_onyen'],
        total_unique_records: tracker.dig('progress', 'adjust_id_lists', 'pubmed', 'adjusted_size').to_i +
                              tracker.dig('progress', 'adjust_id_lists', 'pmc', 'adjusted_size').to_i,
        start_date: tracker['date_range']['start'],
        end_date: tracker['date_range']['end']
      },
      categories: {
        successfully_ingested_and_attached: 'Successfully Ingested and Attached',
        successfully_ingested_metadata_only: 'Successfully Ingested (Metadata Only)',
        successfully_attached: 'Successfully Attached To Existing Work',
        skipped_file_attachment: 'Skipped File Attachment To Existing Work',
        skipped: 'Skipped',
        failed: 'Failed',
        skipped_non_unc_affiliation: 'Skipped (No UNC Affiliation)'
      },
      records: results
    }
  end
end
