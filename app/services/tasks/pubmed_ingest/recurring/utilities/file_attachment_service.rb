# frozen_string_literal: true
require 'aws-sdk-s3'

class Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  PMC_S3_BUCKET = 'pmc-oa-opendata'

  def initialize(config:, tracker:, log_file_path:, full_text_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @full_text_path = full_text_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
  end

  def filter_record?(record)
    return true if super
    pmcid = record.dig('ids', 'pmcid')
    # Skip records that have already been processed if resuming
    return true if @existing_ids.include?(pmcid) || @existing_ids.include?(record.dig('ids', 'pmid'))

    if pmcid.blank?
        # Can only retrieve files using PMCID
      log_attachment_outcome(record, category: category_for_skipped_file_attachment(record), message: 'No PMCID found - can only retrieve files with PMCID', file_name: 'NONE')
      return true
    end

    return false
  end

  def process_record(record)
    pmcid = record['ids']['pmcid']
    return unless pmcid.present?

    retries = 0
    begin
      version_prefix = latest_version_prefix(pmcid)
      if version_prefix.nil?
        log_attachment_outcome(record, category: category_for_skipped_file_attachment(record),
                               message: 'No versions found in S3 for PMCID', file_name: 'NONE')
        return
      end

      version_id = version_prefix.chomp('/')
      pdf_key = "#{version_prefix}#{version_id}.pdf"

      filename = generate_filename_for_work(record.dig('ids', 'work_id'), pmcid)
      file_path = File.join(@full_text_path, filename)

      LogUtilsHelper.double_log("Downloading s3://#{PMC_S3_BUCKET}/#{pdf_key}", :info, tag: 'S3')
      s3_client.get_object(bucket: PMC_S3_BUCKET, key: pdf_key, response_target: file_path)

      file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                    file_path: file_path,
                                                    depositor_onyen: config['depositor_onyen'])
      if file_set
        log_attachment_outcome(record,
                  category: category_for_successful_attachment(record),
                  message: 'PDF successfully attached.',
                  file_name: filename)
      end

    rescue Aws::S3::Errors::NoSuchKey
      log_attachment_outcome(record, category: category_for_skipped_file_attachment(record),
                             message: 'No PDF found in S3 for PMCID', file_name: 'NONE')
    rescue => e
      retries += 1
      if retries <= RETRY_LIMIT
        sleep(1)
        retry
      else
        log_attachment_outcome(record, category: :failed, message: "File attachment failed -- #{e.message}", file_name: 'NONE')
        LogUtilsHelper.double_log("Error processing record: #{e.message}. PMCID: #{pmcid}", :error, tag: 'Attachment')
        Rails.logger.error e.backtrace.join("\n")
      end
    ensure
      sleep(SLEEP_BETWEEN_REQUESTS)
    end
  end

  def latest_version_prefix(pmcid)
    resp = s3_client.list_objects_v2(
      bucket: PMC_S3_BUCKET,
      prefix: "#{pmcid}.",
      delimiter: '/'
    )
    prefixes = resp.common_prefixes.map(&:prefix)
    return nil if prefixes.empty?
    prefixes.sort.last
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: 'us-east-1',
      credentials: Aws::AnonymousCredentials.new
    )
  end
end
