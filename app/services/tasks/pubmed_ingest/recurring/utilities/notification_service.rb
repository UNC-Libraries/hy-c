# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::NotificationService
  def initialize(config:, tracker:, log_file_path:, file_attachment_results_path:)
    @config = config
    @tracker = tracker
    @log_file_path = log_file_path
    @file_attachment_results = load_results(path: file_attachment_results_path)
  end

  def load_results(path:)
    unless File.exist?(path)
      LogUtilsHelper.double_log("Results file not found at #{path}", :error, tag: 'load_and_format_results')
      raise "Results file not found at #{path}"
    end
    raw_results_array = JsonFileUtilsHelper.read_jsonl(path, symbolize_names: true)
    LogUtilsHelper.double_log("Successfully loaded and formatted results from #{path}.", :info, tag: 'load_and_format_results')
    raw_results_array
  end

  def send_summary_email
    summary = LogUtilsHelper.compile_log_summary(@log_file_path)
    recipient = @config['notification_email']
    return unless recipient.present?

    subject = 'PubMed Ingest Notification Summary'
    body = "Dear User,\n\nHere is the summary of the recent PubMed ingest process:\n\n#{summary}\n\nBest regards,\nPubMed Ingest System"
    NotificationUtilsHelper.send_email(to: recipient, subject: subject, body: body)
  end
end
