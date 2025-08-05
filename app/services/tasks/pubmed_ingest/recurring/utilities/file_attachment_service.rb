# frozen_string_literal: true
require 'net/ftp'
require 'tempfile'
require 'stringio'
require 'zlib'
require 'rubygems/package'

class Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService
  include Tasks::IngestHelper
  
  MAX_THREADS = 5
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
    queue = Queue.new
    @records.each { |record| queue << record }

    threads = Array.new(MAX_THREADS) do
      Thread.new do
        while !queue.empty?
          record = queue.pop(true) rescue nil
          next unless record

          process_record(record)
        end
      end
    end
    threads.each(&:join)
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

    Set.new(
        File.readlines(@log_file).map do |line|
          result = JSON.parse(line.strip)
          [result.dig('ids', 'pmcid'), result.dig('ids', 'pmid')]
        end.flatten.compact
    )
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
    if work_id.present? && has_fileset?(work_id)
      log_result(record, category: :skipped, message: 'Work already has files attached')
      return true
    end

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
         begin
            uri = URI.parse(tgz_url)
            tgz_data = fetch_ftp_binary(uri)
            process_and_attach_tgz_file(record, tgz_data)
          rescue => ftp_error
            Rails.logger.warn("TGZ FTP fetch failed for #{pmcid}: #{ftp_error.message}")
          end
      end

        # if tgz_url.present?
        #   tgz_response = HTTParty.get(tgz_url, timeout: 20)
        #   if tgz_response.code == 200
        #     process_and_attach_tgz_file(record, tgz_response.body)
        #   else
        #     Rails.logger.warn("TGZ fetch failed for #{pmcid}: #{tgz_response.code}")
        #   end
        # end
    rescue => e
      retries += 1
      if retries <= RETRY_LIMIT
        sleep(1)
        retry
      else
        log_result(record, category: :failed, message: e.message)
      end
    ensure
      sleep(SLEEP_BETWEEN_REQUESTS)
    end
  end

  def fetch_ftp_binary(uri)
    Net::FTP.open(uri.host) do |ftp|
      ftp.login
      ftp.passive = true
      remote_path = uri.path
      data = +''
      ftp.getbinaryfile(remote_path, nil) { |block| data << block }
      return data
    end
  end

 def attach_pdf_to_work_with_binary(record, pdf_binary)
    article_id = record.dig('ids', 'article_id')
    return log_result(record, category: :skipped, message: 'No article ID found to attach PDF') unless article_id.present?

    begin
      work = Article.find(article_id)
      depositor = ::User.find_by(uid: 'admin')
      raise "No depositor found" unless depositor

      filename = "#{record.dig('ids', 'pmcid')}.pdf"
      path = File.join(@full_text_path, filename)
      LogUtilsHelper.double_log("PDF attachment path: #{path}", :info, tag: 'File Attachment Service')
      File.open(path, 'wb') { |f| f.write(pdf_binary) }

      file_set = attach_pdf_to_work(work, path, depositor, work.visibility)

      if file_set.nil?
        raise "FileSet attachment failed via IngestHelper"
      end

      # Update work metadata if needed
      work.reload
      work.representative_id ||= file_set.id
      work.thumbnail_id ||= file_set.id
      work.rendering_ids << file_set.id.to_s unless work.rendering_ids.include?(file_set.id.to_s)
      work.save!
      work.update_index

      log_result(record, category: :successfully_attached, message: 'PDF successfully attached.')

    rescue => e
      log_result(record, category: :failed, message: e.message)
      Rails.logger.error "PDF attachment failed for #{record.dig('ids', 'pmcid')}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

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

            filename = File.basename(rel_path)
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