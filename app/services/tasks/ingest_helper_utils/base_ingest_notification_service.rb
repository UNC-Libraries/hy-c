# frozen_string_literal: true
class Tasks::IngestHelperUtils::BaseIngestNotificationService
  include Tasks::IngestHelperUtils::ReportingHelper
  INGEST_RESULTS_FILENAME = 'ingest_results.zip'

  def initialize(config:, tracker:, output_dir:, file_attachment_results_path:, max_display_rows: 100)
    @config = config
    @tracker = tracker
    @output_dir = output_dir
    @file_attachment_results_path = file_attachment_results_path
    @max_display_rows = max_display_rows
  end

  def run
    formatted_results = load_results(path: @file_attachment_results_path, tracker: @tracker)
    send_summary_email(formatted_results)
  end

  def send_summary_email(attachment_results)
    return if already_sent?

    LogUtilsHelper.double_log('Finalizing report and sending notification email...', :info, tag: 'send_summary_email')

    report = Tasks::IngestHelperUtils::IngestReportingService.generate_report(
      ingest_output: attachment_results,
      source_name: source_name
    )

    populate_headers!(report)
    report[:categories] = category_labels
    report[:truncated_categories] = generate_truncated_categories(report[:records], max_rows: @max_display_rows)
    report[:max_display_rows] = @max_display_rows

    if @tracker['progress']['prepare_email_attachments']['completed']
      LogUtilsHelper.double_log('Email attachments already prepared according to tracker. Skipping attachment generation.', :info, tag: 'send_summary_email')
      zip_path = File.join(@output_dir, INGEST_RESULTS_FILENAME)
    else
      LogUtilsHelper.double_log('Generating CSV attachments for email...', :info, tag: 'send_summary_email')
      csv_paths = generate_result_csvs(results: report[:records], csv_output_dir: @output_dir)
      zip_path  = compress_result_csvs(csv_paths: csv_paths, zip_output_dir: @output_dir)
      @tracker['progress']['prepare_email_attachments']['completed'] = true
      @tracker.save
    end

    send_mail(report, zip_path)

    mark_as_sent!
    LogUtilsHelper.double_log('Email notification sent successfully.', :info, tag: 'send_summary_email')
  rescue StandardError => e
    LogUtilsHelper.double_log("Failed to send email notification: #{e.message}", :error, tag: 'send_summary_email')
    Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    raise e
  end

  private

  def already_sent?
    if @tracker['progress']['send_summary_email']['completed']
      LogUtilsHelper.double_log('Skipping email notification as it has already been sent.', :info, tag: 'send_summary_email')
      true
    else
      false
    end
  end

  def mark_as_sent!
    @tracker['progress']['send_summary_email']['completed'] = true
    @tracker.save
  end

  def category_labels
    {
      successfully_ingested_and_attached: 'Successfully Ingested and Attached',
      successfully_ingested_metadata_only: 'Successfully Ingested (Metadata Only)',
      successfully_attached: 'Successfully Attached To Existing Work',
      skipped_file_attachment: 'Skipped File Attachment To Existing Work',
      skipped: 'Skipped',
      failed: 'Failed',
      skipped_non_unc_affiliation: 'Skipped (No UNC Affiliation)'
    }
  end

  # --- Abstract methods to override in subclasses ---
  def source_name
    raise NotImplementedError
  end

  def populate_headers!(report)
    raise NotImplementedError
  end

  def send_mail(report, zip_path)
    raise NotImplementedError
  end

  # Optional helper for subclasses
  def calculate_rows_in_csv(path)
    return 0 unless File.exist?(path)
    CSV.read(path, headers: true).length
  end
end
