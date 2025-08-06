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
    work_id = record.dig('ids', 'article_id')
    # Skip records that have already been processed if resuming
    return true if @existing_ids.include?(pmcid) || @existing_ids.include?(record.dig('ids', 'pmid'))
    if pmcid.blank?
        # Can only retrieve files using PMCID
      log_result(record, category: :skipped, message: 'No PMCID found')
      return true
    end
    # WIP: Temporarily do not filter out works that already have files attached
    # if work_id.present? && has_fileset?(work_id)
    #   log_result(record, category: :skipped, message: 'Work already has files attached')
    #   return true
    # end

    return false
  end

  def has_fileset?(work_id)
    work = WorkUtilsHelper.fetch_work_data_by_id(work_id)
    work && work[:file_set_ids]&.any?
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
      raise "No PDF or TGZ link found" if pdf_url.blank? && tgz_url.blank?

      if pdf_url.present?
        uri = URI.parse(pdf_url)
        pdf_data = fetch_ftp_binary(uri)
        attach_pdf_to_work_with_binary(record, pdf_data)
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
        log_result(record, category: :successfully_ingested, message: 'No PDF or TGZ link found, skipping attachment')
      else
        log_result(record, category: :failed, message: e.message)
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
      data = +' '
      ftp.getbinaryfile(remote_path, nil) { |block| data << block }
      data
    end
  end

  def attach_pdf_to_work_with_binary(record, pdf_binary)
    article_id = record.dig('ids', 'article_id')
    return log_result(record, category: :skipped, message: 'No article ID found to attach PDF') unless article_id.present?

    article = Article.find(article_id)
    pmcid = record.dig('ids', 'pmcid')
    filename = generate_filename_for_work(article.id, pmcid)
    Tempfile.create([File.basename(filename, '.pdf'), '.pdf']) do |tempfile|
      tempfile.binmode
      tempfile.write(pdf_binary)
      tempfile.flush
      file_path = File.join(@full_text_path, filename)
      absolute_file_path = File.expand_path(file_path)
      FileUtils.cp(tempfile.path, absolute_file_path)
      FileUtils.chmod(0o644, absolute_file_path) 

      skipped_row = {
        'file_name' => filename,
        'pmid' => record.dig('ids', 'pmid'),
        'pmcid' => pmcid
      }

      LogUtilsHelper.double_log("Attaching PDF from #{absolute_file_path} to article #{article.id}", :info, tag: 'Attachment')
      attach_pdf(article, skipped_row)
    end
    log_result(record, category: :successfully_attached, message: 'PDF successfully attached.')
  rescue => e
    log_result(record, category: :failed, message: "PDF attachment failed: #{e.message}")
    LogUtilsHelper.double_log("[FileAttachmentService] PDF attachment failed for #{article_id}: #{e.message}", :error, tag: 'Attachment')
  end

  # def process_and_attach_tgz_file(record, tgz_binary)
  #   pmcid = record.dig('ids', 'pmcid')
  #   article_id = record.dig('ids', 'article_id')
  #   return log_result(record, category: :skipped, message: 'No article ID found to attach TGZ') unless article_id.present?

  #   begin
  #     work = Article.find(article_id)
  #     depositor = ::User.find_by(uid: 'admin')
  #     raise "No depositor found" unless depositor

  #     pdf_paths = []

  #     tgz_path = File.join(@full_text_path, "#{pmcid}.tar.gz")
  #     tgz_absolute_path = File.expand_path(tgz_path)
  #     LogUtilsHelper.double_log("Processing TGZ file for PMCID #{pmcid} at #{tgz_absolute_path}", :info, tag: 'TGZ Processing')
  #     File.open(tgz_absolute_path, 'wb') { |f| f.write(tgz_binary) }

  #      # Check if the file is actually gzip compressed
  #     if gzip_compressed?(tgz_absolute_path)
  #       # Process as gzip-compressed tar
  #       Zlib::GzipReader.open(tgz_absolute_path) do |gz|
  #         Gem::Package::TarReader.new(gz) do |tar|
  #           tar.each do |entry|
  #             next unless entry.file?

  #             # We only care about .pdf files 
  #             rel_path = entry.full_name
  #             next unless rel_path.downcase.end_with?('.pdf')

  #             filename = generate_filename_for_work(work.id, pmcid)     
  #             file_path = File.join(@full_text_path, filename)
  #             file_absolute_path = File.expand_path(file_path)
  #             File.open(file_absolute_path, 'wb') { |f| f.write(entry.read) }
  #             FileUtils.chmod(0o644, file_absolute_path)
  #             pdf_paths << file_absolute_path
  #           end
  #         end
  #       end
  #     else
  #       File.open(tgz_absolute_path, 'rb') do |file|
  #         magic = file.read(8).unpack('H*').first
  #         LogUtilsHelper.double_log("Unrecognized TGZ file format for #{pmcid}. Magic bytes: #{magic}", :error, tag: 'TGZ Format')
  #       end
  #       raise "Unrecognized file format for #{pmcid}, cannot process as TGZ or tar."

  #       # Process as uncompressed tar or try to handle as direct archive
  #       LogUtilsHelper.double_log("File is not gzip compressed, trying as uncompressed tar for #{pmcid}", :info, tag: 'TGZ Processing')
        
  #       File.open(tgz_absolute_path, 'rb') do |file|
  #         Gem::Package::TarReader.new(file) do |tar|
  #           tar.each do |entry|
  #             next unless entry.file?

  #             # We only care about .pdf files 
  #             rel_path = entry.full_name
  #             next unless rel_path.downcase.end_with?('.pdf')

  #             filename = generate_filename_for_work(work.id, pmcid)     
  #             file_path = File.join(@full_text_path, filename)
  #             file_absolute_path = File.expand_path(file_path)
  #             File.open(file_absolute_path, 'wb') { |f| f.write(entry.read) }
  #             FileUtils.chmod(0o644, file_absolute_path)
  #             pdf_paths << file_absolute_path
  #           end
  #         end
  #       end
  #     end

  #     if pdf_paths.empty?
  #       raise "No PDF files found in TGZ archive"
  #     end

  #     pdf_paths.each do |path|
  #       file_set = attach_pdf_to_work(work, path, depositor, work.visibility)
  #       raise "Attachment failed for #{path}" unless file_set
  #     end

  #     work.reload
  #     work.update_index

  #     log_result(record, category: :successfully_attached, message: "Extracted and attached PDFs from TGZ: #{pdf_paths.map { |p| File.basename(p) }.join(', ')}")

  #   rescue => e
  #     log_result(record, category: :failed, message: "TGZ PDF processing failed: #{e.message}")
  #     Rails.logger.error "TGZ PDF processing failed for #{pmcid}: #{e.message}"
  #     Rails.logger.error e.backtrace.join("\n")
  #   end
  # end


  def process_and_attach_tgz_file(record, tgz_binary)
    pmcid = record.dig('ids', 'pmcid')
    article_id = record.dig('ids', 'article_id')
    return log_result(record, category: :skipped, message: 'No article ID found to attach TGZ') unless article_id.present?

    begin
      work = Article.find(article_id)
      depositor = ::User.find_by(uid: 'admin')
      raise "No depositor found" unless depositor

      pdf_paths = []

      tgz_path = File.join(@full_text_path, "#{pmcid}.tar.gz")
      File.open(tgz_path, 'wb') { |f| f.write(tgz_binary) }

      Zlib::GzipReader.open(tgz_path) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            next unless entry.file?

            # We only care about .pdf files 
            rel_path = entry.full_name
            next unless rel_path.downcase.end_with?('.pdf')

            filename = generate_filename_for_work(work.id, pmcid)
            file_path = File.join(@full_text_path, filename)
            File.open(file_path, 'wb') { |f| f.write(entry.read) }
            pdf_paths << file_path
          end
        end
      end

      if pdf_paths.empty?
        raise "No PDF files found in TGZ archive"
      end

      pdf_paths.each do |path|
        file_set = attach_pdf_to_work(work, path, depositor, work.visibility)
        raise "Attachment failed for #{path}" unless file_set
      end

      work.reload
      work.update_index

      log_result(record, category: :successfully_attached, message: "Extracted and attached PDFs from TGZ: #{pdf_paths.map { |p| File.basename(p) }.join(', ')}")

    rescue => e
      log_result(record, category: :failed, message: "TGZ PDF processing failed: #{e.message}")
      Rails.logger.error "TGZ PDF processing failed for #{pmcid}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def group_permissions(admin_set)
    @group_permissions ||= WorkUtilsHelper.get_permissions_attributes(admin_set.id)
  end

  def attach_pdf(article, skipped_row)
    Rails.logger.info("[AttachPDF] Attaching PDF for article #{article.id}")

    file_path = File.join(@full_text_path, skipped_row['file_name'])
    Rails.logger.info("[AttachPDF] Resolved file path: #{file_path}")

    unless File.exist?(file_path)
      error_msg = "[AttachPDF] File not found at path: #{file_path}"
      Rails.logger.error(error_msg)
      raise StandardError, error_msg
    end

    depositor = ::User.find_by(uid: 'admin')
    raise "No depositor found" unless depositor

    pdf_file = attach_pdf_to_work(article, file_path, depositor, article.visibility)

    if pdf_file.nil?
      ids = [skipped_row['pmid'], skipped_row['pmcid']].compact.join(', ')
      error_msg = "[AttachPDF] ERROR: Attachment returned nil for identifiers: #{ids}"
      Rails.logger.error(error_msg)
      raise StandardError, error_msg
    end

    begin
      pdf_file.update!(permissions_attributes: group_permissions(@admin_set))
      Rails.logger.info("[AttachPDF] Permissions successfully set on file #{pdf_file.id}")
    rescue => e
      Rails.logger.warn("[AttachPDF] Could not update permissions: #{e.message}")
      raise e
    end
  end

  def gzip_compressed?(file_path)
    # Check if file starts with gzip magic number (1f 8b)
    File.open(file_path, 'rb') do |file|
      magic = file.read(2)
      return false if magic.nil? || magic.length < 2
      magic.unpack('C*') == [0x1f, 0x8b]
    end
  rescue
    false
  end


  def generate_filename_for_work(work_id, pmcid)
    work = WorkUtilsHelper.fetch_work_data_by_id(work_id)
    return nil unless work
    suffix = work[:file_set_ids].present? ? format('%03d', work[:file_set_ids].size + 1) : '001'
    "#{pmcid}_#{suffix}.pdf"
  end

  def log_result(record, category:, message:)
    entry = {
      ids: record['ids'],
      timestamp: Time.now.utc.iso8601,
      category: category,
      message: message
    }
    @tracker.save
    File.open(@log_file, 'a') { |f| f.puts(entry.to_json) }
  end
end