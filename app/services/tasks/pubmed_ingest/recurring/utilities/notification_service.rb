# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::NotificationService
  def initialize(config:, tracker:, log_file_path:, file_attachment_results_path:, max_display_rows: 100)
    @config = config
    @tracker = tracker
    @log_file_path = log_file_path
    @file_attachment_results_path = file_attachment_results_path
    @max_display_rows = max_display_rows
  end

  def run
    formatted_attachment_results = load_results(path: @file_attachment_results_path)
    send_summary_email(formatted_attachment_results)
  end

  def send_summary_email(attachment_results)
    if @tracker['progress']['send_summary_email']['completed']
      LogUtilsHelper.double_log('Skipping email notification as it has already been sent.', :info, tag: 'send_summary_email')
      return
    end
    # Generate report, log, send email
    LogUtilsHelper.double_log('Finalizing report and sending notification email...', :info, tag: 'send_summary_email')
    begin
      report = Tasks::PubmedIngest::SharedUtilities::PubmedReportingService.generate_report(attachment_results)
      report[:headers][:depositor] = @tracker['depositor_onyen']
      report[:headers][:total_unique_records] =
        @tracker['progress']['adjust_id_lists']['pubmed']['adjusted_size'] +
        @tracker['progress']['adjust_id_lists']['pmc']['adjusted_size']
      report[:headers][:start_date] = Date.parse(@tracker['date_range']['start']).strftime('%Y-%m-%d')
      report[:headers][:end_date]   = Date.parse(@tracker['date_range']['end']).strftime('%Y-%m-%d')
      report[:categories] = {
                            successfully_ingested_and_attached: 'Successfully Ingested and Attached',
                            successfully_ingested_metadata_only: 'Successfully Ingested (Metadata Only)',
                            successfully_attached: 'Successfully Attached To Existing Work',
                            skipped_file_attachment: 'Skipped File Attachment To Existing Work',
                            skipped: 'Skipped',
                            failed: 'Failed',
                            skipped_non_unc_affiliation: 'Skipped (No UNC Affiliation)'
                          }
      report[:truncated_categories] = Tasks::IngestHelperUtils::ReportingHelper.generate_truncated_categories(report[:records], max_rows: @max_display_rows)
      report[:max_display_rows] = @max_display_rows
      csv_paths = Tasks::IngestHelperUtils::ReportingHelper.generate_result_csvs(
        results: report[:records],
        csv_output_dir: File.dirname(@log_file_path)
    )
      zip_path  = Tasks::IngestHelperUtils::ReportingHelper.compress_result_csvs(
        csv_paths: csv_paths,
        zip_output_dir: File.dirname(@log_file_path)
    )
      PubmedReportMailer.truncated_pubmed_report_email(report, zip_path).deliver_now
      @tracker['progress']['send_summary_email']['completed'] = true
      @tracker.save
      LogUtilsHelper.double_log('Email notification sent successfully.', :info, tag: 'send_summary_email')
    rescue StandardError => e
      LogUtilsHelper.double_log("Failed to send email notification: #{e.message}", :error, tag: 'send_summary_email')
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    end
  end

  private

  def load_results(path:)
    unless File.exist?(path)
      LogUtilsHelper.double_log("Results file not found at #{path}", :error, tag: 'load_and_format_results')
      raise "Results file not found at #{path}"
    end
    raw_results_array = JsonFileUtilsHelper.read_jsonl(path, symbolize_names: true)
    LogUtilsHelper.double_log("Successfully loaded and formatted results from #{path}.", :info, tag: 'load_and_format_results')
    Tasks::IngestHelperUtils::ReportingHelper.format_results_for_reporting(
        raw_results_array: raw_results_array,
        tracker: @tracker
    )
  end
end
