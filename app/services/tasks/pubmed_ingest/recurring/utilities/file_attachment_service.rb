# frozen_string_literal: true
require 'net/ftp'
require 'zlib'
require 'rubygems/package'

class Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  def initialize(config:, tracker:, log_file_path:, full_text_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path)
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
    url = "https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi?id=#{pmcid}"
    retries = 0
    begin
      response = HTTParty.get(url, timeout: 10)
      raise "Bad response: #{response.code}" unless response.code == 200

      doc = Nokogiri::XML(response.body)
      error_node = doc.at_xpath('//error')
      if error_node
        error_code = error_node['code']
        Rails.logger.warn "Skipping PMCID #{pmcid} — Open Access API Error: #{error_code}"
        log_attachment_outcome(record, category: :skipped_file_attachment, message: "Open Access API Error - #{error_code}", file_name: 'NONE')
        return
      end
      pdf_url = doc.at_xpath('//record/link[@format="pdf"]')&.[]('href')
      tgz_url = doc.at_xpath('//record/link[@format="tgz"]')&.[]('href')
      raise 'No PDF or TGZ link found' if pdf_url.blank? && tgz_url.blank?

      if pdf_url.present?
        uri = URI.parse(pdf_url)
        filename = generate_filename_for_work(record.dig('ids', 'work_id'), pmcid)
        file_path = File.join(@full_text_path, filename)
        fetch_ftp_binary(uri, local_file_path: file_path)
        file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                      file_path: file_path,
                                                      depositor_onyen: config['depositor_onyen'])
        if file_set
          log_attachment_outcome(record,
                    category: category_for_successful_attachment(record),
                    message: 'PDF successfully attached.',
                    file_name: filename)
        end
      elsif tgz_url.present?
        tgz_path = File.join(@full_text_path, "#{pmcid}.tar.gz")
        uri = URI.parse(tgz_url)
        tgz_data = fetch_ftp_binary(uri, local_file_path: tgz_path)
        process_and_attach_tgz_file(record, tgz_path)
      end

    rescue => e
      # Do not retry if no PDF or TGZ link is found in the response
      if e.message.include?('No PDF or TGZ link found')
        log_attachment_outcome(record, category: category_for_skipped_file_attachment(record), message: 'No PDF or TGZ link found, skipping attachment', file_name: 'NONE')
      else
        retries += 1
        if retries <= RETRY_LIMIT
          sleep(1)
          retry
        else
          log_attachment_outcome(record, category: :failed, message: "File attachment failed -- #{e.message}", file_name: 'NONE')
          LogUtilsHelper.double_log("Error processing record: #{e.message}. Request URL: #{url}", :error, tag: 'Attachment')
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    ensure
      sleep(SLEEP_BETWEEN_REQUESTS)
    end
  end

  def fetch_ftp_binary(uri, local_file_path:)
    LogUtilsHelper.double_log("Fetching FTP file from #{uri}", :info, tag: 'FTP')
    Net::FTP.open(uri.host) do |ftp|
      ftp.login
      ftp.passive = true
      remote_path = uri.path
      remote_path = "/#{remote_path}" unless remote_path.start_with?('/')
      ftp.getbinaryfile(remote_path, local_file_path)
    end
    local_file_path
  end

  def safe_gzip_reader(path)
    content = File.binread(path)
    gzip_start = content.index("\x1F\x8B".b)
    raise 'No GZIP header found in file' unless gzip_start

    str_io = StringIO.new(content[gzip_start..])
    Zlib::GzipReader.new(str_io)
  end

  def process_and_attach_tgz_file(record, tgz_path)
    pmcid = record.dig('ids', 'pmcid')
    work_id = record.dig('ids', 'work_id')
    return log_attachment_outcome(record, category: category_for_skipped_file_attachment(record), message: 'No article ID found to attach TGZ', file_name: 'NONE') if work_id.blank?

    begin
      work = Article.find(work_id)
      depositor = ::User.find_by(uid: @config['depositor_onyen'])
      raise 'No depositor found' unless depositor

      pdf_count = 0

      tgz_absolute_path = File.expand_path(tgz_path)

      gz = safe_gzip_reader(tgz_absolute_path)
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each do |entry|
          next unless entry.file?
          next unless entry.full_name.downcase.end_with?('.pdf')

          pdf_binary = entry.read
          LogUtilsHelper.double_log("Extracting PDF from TGZ: #{entry.full_name} (#{pdf_binary.bytesize} bytes)", :info, tag: 'TGZ Processing')

          filename = generate_filename_for_work(work.id, pmcid)
          file_path = File.join(@full_text_path, filename)
          File.binwrite(file_path, pdf_binary)


          # file_set = attach_df_to_work_with_file_path!(record, file_path, @config['depositor_onyen'])
          file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                        file_path: file_path,
                                                        depositor: @config['depositor_onyen'])
          if file_set
            log_attachment_outcome(record,
                      category: :successfully_attached,
                      message: 'PDF successfully attached from TGZ.',
                      file_name: filename)
            pdf_count += 1
          end
        end
      end
      gz.close

      raise 'No PDF files found in TGZ archive' if pdf_count == 0

      work.reload
      work.update_index

    rescue => e
      log_attachment_outcome(record, category: :failed, message: "TGZ PDF processing failed: #{e.message}", file_name: 'NONE')
      Rails.logger.error "TGZ PDF processing failed for #{pmcid}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
