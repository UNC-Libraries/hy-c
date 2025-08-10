# frozen_string_literal: true
require 'net/ftp'
require 'tempfile'
require 'zlib'
require 'rubygems/package'

class Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService
  include Tasks::IngestHelper

  RETRY_LIMIT = 3
  SLEEP_BETWEEN_REQUESTS = 0.25

  def initialize(config:, tracker:, output_path:, full_text_path:, metadata_ingest_result_path:)
    @log_file = File.join(output_path, 'attachment_results.jsonl')
    @config = config
    @tracker = tracker
    @output_path = output_path
    @full_text_path = full_text_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_existing_attachment_ids
    @records = load_records_to_attach
  end

  def run
    @records.each_with_index do |record, index|
      LogUtilsHelper.double_log("Processing record #{index + 1} of #{@records.size}", :info, tag: 'Attachment')
      process_record(record)
    end
  end

  def load_records_to_attach
    LogUtilsHelper.double_log('Loading records to attach files to.', :info, tag: 'File Attachment Service')
    records = []
    File.foreach(@metadata_ingest_result_path) do |line|
      record = JSON.parse(line)
      next if filter_record?(record)
      records << record
    end
    LogUtilsHelper.double_log("Loaded #{records.size} records to attach files to.", :info, tag: 'File Attachment Service')
    records
  end

  def load_existing_attachment_ids
    return Set.new unless File.exist?(@log_file)
    Set.new(File.readlines(@log_file).map { |line| JSON.parse(line.strip).values_at('ids').flat_map(&:values).compact }.flatten)
  end

  def filter_record?(record)
    pmcid = record.dig('ids', 'pmcid')
    work_id = record.dig('ids', 'work_id')
    # Skip records that have already been processed if resuming
    return true if @existing_ids.include?(pmcid) || @existing_ids.include?(record.dig('ids', 'pmid'))
    if pmcid.blank?
        # Can only retrieve files using PMCID
      log_result(record, category: :skipped, message: 'No PMCID found', file_name: 'NONE')
      return true
    end
    # WIP: Temporarily do not filter out works that already have files attached
    if work_id.present? && has_fileset?(work_id)
      log_result(record, category: :skipped, message: 'Work already has files attached', file_name: 'NONE')
      return true
    end

    return false
  end

  def has_fileset?(work_id)
    work = WorkUtilsHelper.fetch_work_data_by_id(work_id)
    return false if work.nil?
    work[:file_set_ids]&.any?
  end

  def process_record(record)
    pmcid = record['ids']['pmcid']
    return unless pmcid.present?
    retries = 0
    begin
      LogUtilsHelper.double_log("Fetching Open Access info for #{pmcid}", :info, tag: 'OA Fetch')
      response = HTTParty.get("https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi?id=#{pmcid}", timeout: 10)
      raise "Bad response: #{response.code}" unless response.code == 200

      doc = Nokogiri::XML(response.body)
      pdf_url = doc.at_xpath('//record/link[@format="pdf"]')&.[]('href')
      tgz_url = doc.at_xpath('//record/link[@format="tgz"]')&.[]('href')
      raise 'No PDF or TGZ link found' if pdf_url.blank? && tgz_url.blank?

      if pdf_url.present?
        uri = URI.parse(pdf_url)
        pdf_data = fetch_ftp_binary(uri)
        filename = generate_filename_for_work(record.dig('ids', 'work_id'), pmcid)
        attach_pdf_to_work_with_binary!(record, pdf_data, filename)
      elsif tgz_url.present?
        uri = URI.parse(tgz_url)
        tgz_data = fetch_ftp_binary(uri)
        process_and_attach_tgz_file(record, tgz_data)
      end
    rescue => e
      retries += 1
      if retries <= RETRY_LIMIT
        sleep(1)
        retry
      elsif e.message.include?('No PDF or TGZ link found')
        log_result(record, category: :successfully_ingested, message: 'No PDF or TGZ link found, skipping attachment', file_name: 'NONE')
      else
        log_result(record, category: :failed, message: e.message, file_name: 'NONE')
        LogUtilsHelper.double_log("Error processing record: #{e.message}", :error, tag: 'Attachment')
      end
    ensure
      sleep(SLEEP_BETWEEN_REQUESTS)
    end
  end

  def fetch_ftp_binary(uri)
    LogUtilsHelper.double_log("Fetching FTP file from #{uri}", :info, tag: 'FTP')
    Net::FTP.open(uri.host) do |ftp|
      ftp.login
      ftp.passive = true
      remote_path = uri.path
      # Normalize remote path to ensure it starts with a slash
      remote_path = "/#{remote_path}" unless remote_path.start_with?('/')
      data = +''
      ftp.getbinaryfile(remote_path, nil) { |block| data << block }
      data
    end
  end


  def safe_gzip_reader(path)
    content = File.binread(path)
    gzip_start = content.index("\x1F\x8B".b)
    raise 'No GZIP header found in file' unless gzip_start

    str_io = StringIO.new(content[gzip_start..])
    Zlib::GzipReader.new(str_io)
  end


  def process_and_attach_tgz_file(record, tgz_binary)
    pmcid = record.dig('ids', 'pmcid')
    work_id = record.dig('ids', 'work_id')
    return log_result(record, category: :skipped, message: 'No article ID found to attach TGZ', file_name: 'NONE') if work_id.blank?

    begin
      work = Article.find(work_id)
      depositor = ::User.find_by(uid: 'admin')
      raise 'No depositor found' unless depositor

      pdf_count = 0
      attached_files = []

      tgz_path = File.join(@full_text_path, "#{pmcid}.tar.gz")
      tgz_absolute_path = File.expand_path(tgz_path)
      File.open(tgz_absolute_path, 'wb') { |f| f.write(tgz_binary) }

      gz = safe_gzip_reader(tgz_absolute_path)
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each do |entry|
          next unless entry.file?
          next unless entry.full_name.downcase.end_with?('.pdf')

          pdf_binary = entry.read
          LogUtilsHelper.double_log("Extracting PDF from TGZ: #{entry.full_name} (#{pdf_binary.bytesize} bytes)", :info, tag: 'TGZ Processing')

          # Attach the PDF binary directly
          filename = generate_filename_for_work(work.id, pmcid)
          file_set, basename = attach_pdf_to_work_with_binary!(record, pdf_binary, filename)
          if file_set
            log_result(record,
                       category: :successfully_attached,
                       message: 'PDF successfully attached from TGZ.',
                       file_name: basename)
            pdf_count += 1
          end
        end
      end
      gz.close

      # Clean up the temporary TGZ file
      File.delete(tgz_absolute_path) if File.exist?(tgz_absolute_path)

      if pdf_count == 0
        raise 'No PDF files found in TGZ archive'
      end

      work.reload
      work.update_index

    rescue => e
      log_result(record, category: :failed, message: "TGZ PDF processing failed: #{e.message}", file_name: 'NONE')
      Rails.logger.error "TGZ PDF processing failed for #{pmcid}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def group_permissions(admin_set)
    @group_permissions ||= WorkUtilsHelper.get_permissions_attributes(admin_set.id)
  end

  def generate_filename_for_work(work_id, pmcid)
    work = WorkUtilsHelper.fetch_work_data_by_id(work_id)
    return nil unless work
    suffix = work[:file_set_ids].present? ? format('%03d', work[:file_set_ids].size + 1) : '001'
    "#{pmcid}_#{suffix}.pdf"
  end

  def log_result(record, category:, message:, file_name: nil)
    entry = {
      ids: record['ids'],
      timestamp: Time.now.utc.iso8601,
      category: category,
      message: message,
      file_name: file_name
    }
    @tracker.save
    File.open(@log_file, 'a') { |f| f.puts(entry.to_json) }
  end
end
