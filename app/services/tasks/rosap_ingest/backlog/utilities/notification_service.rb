# frozen_string_literal: true
class Tasks::RosapIngest::Backlog::Utilities::NotificationService < Tasks::IngestHelperUtils::BaseIngestNotificationService

    # Override for all-caps subject line
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
