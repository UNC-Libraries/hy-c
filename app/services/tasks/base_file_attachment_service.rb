# frozen_string_literal: true
class Tasks::BaseFileAttachmentService
  include Tasks::IngestHelper
  include Tasks::IngestResultLogHelper

  RETRY_LIMIT = 3
  SLEEP_BETWEEN_REQUESTS = 0.25

  attr_reader :config, :tracker, :output_path, :admin_set, :write_buffer

  def initialize(config:, tracker:, output_path:)
    @config = config
    @tracker = tracker
    @output_path = output_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @write_buffer = []
    @flush_threshold = 100
  end

  def run
    work_ids = []
    fetch_attachment_candidates.each_with_index do |record, index|
      LogUtilsHelper.double_log("Processing record #{index + 1}", :info, tag: self.class.name)
      process_record(record)
      work_ids << record.dig('ids', 'work_id') if record.dig('ids', 'work_id').present?
    end

    work_ids.uniq.each { |id| sync_permissions_and_state!(id, config['depositor_onyen']) }
  end

  # overridable by subclasses

  def process_record(record)
    raise NotImplementedError, 'Subclasses must implement process_record'
  end

  # shared helpers

  def filter_record?(record)
    work_id = record.dig('ids', 'work_id')
    category = record['category']
  # Skip records that have already been processed if resuming
    return true if @existing_ids.include?(work_id)
  # Skip records that were skipped due to no UNC affiliation
    case category
    when 'skipped_non_unc_affiliation'
      log_attachment_outcome(record, category: :skipped_non_unc_affiliation, message: 'N/A', file_name: 'NONE')
      return true
    when 'failed'
      log_attachment_outcome(record, category: :failed, message: record['pdf_attached'] || 'No message provided',
                            file_name: 'NONE')
      return true
    end
  # Skip if work already has files attached
    if work_id.present? && has_fileset?(work_id)
      log_attachment_outcome(record, category: :skipped, message: 'Already exists and has files attached', file_name: 'NONE')
      return true
    end

    return false
  end

  def fetch_attachment_candidates
    records = []
    LogUtilsHelper.double_log('Loading records to attach files to.', :info, tag: 'File Attachment Service')
    File.foreach(@metadata_ingest_result_path) do |line|
      record = JSON.parse(line)
      next if filter_record?(record)
      records << record
    end
    LogUtilsHelper.double_log("Loaded #{records.size} records to attach files to.", :info, tag: 'File Attachment Service')
    records
  end

  def load_seen_attachment_ids
    return Set.new unless File.exist?(@log_file)
    Set.new(File.readlines(@log_file).map { |line| JSON.parse(line.strip).values_at('ids').flat_map(&:values).compact }.flatten)
  end

  def has_fileset?(work_id)
    work = WorkUtilsHelper.fetch_work_data_by_id(work_id)
    work && work[:file_set_ids]&.any?
  end

  def generate_filename_for_work(work_id, prefix)
    work = WorkUtilsHelper.fetch_work_data_by_id(work_id)
    suffix = work[:file_set_ids].present? ? format('%03d', work[:file_set_ids].size + 1) : '001'
    "#{prefix}_#{suffix}.pdf"
  end

  def attach_and_log(record, file_path, message:)
    file_set = attach_pdf_to_work_with_file_path!(record, file_path, config['depositor_onyen'])
    if file_set
      log_attachment_outcome(record, category: :successfully_attached, message: message, file_name: File.basename(file_path))
    end
  end

  def log_attachment_outcome(record, category:, message:, file_name: nil)
    entry = {
      ids: record['ids'],
      timestamp: Time.now.utc.iso8601,
      category: category,
      message: message,
      file_name: file_name
    }
    tracker.save
    File.open(File.join(output_path, 'attachment_results.jsonl'), 'a') { |f| f.puts(entry.to_json) }
  end

    # Determine category for records that are skipped for file attachment
    # - If the record existed before the current run, categorize as :skipped_file_attachment
    # - Otherwise, categorize as :successfully_ingested_metadata_only
  def category_for_skipped_file_attachment(record)
    record['category'] == 'skipped' ? :skipped_file_attachment : :successfully_ingested_metadata_only
  end

    # Determine category for file attachment success
    # - If the record existed before the current run, categorize as :successfully_attached
    # - Otherwise, categorize as :successfully_ingested_and_attached
  def category_for_successful_attachment(record)
    record['category'] == 'skipped' ? :successfully_attached : :successfully_ingested_and_attached
  end
end
