# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService
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
    work_id = record.dig('work', 'id')
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
      raise 'No PDF link found' if pdf_url.blank?

      pdf_response = HTTParty.get(pdf_url, timeout: 15)
      raise "PDF fetch failed: #{pdf_response.code}" unless pdf_response.code == 200

      file_path = File.join(@full_text_path, "#{pmcid}.pdf")
      File.open(file_path, 'wb') { |f| f.write(pdf_response.body) }

      log_result(record, category: :successfully_attached, message: 'Downloaded PDF')
    rescue => e
      retries += 1
      if retries <= RETRY_LIMIT
        sleep(1)
        retry
      else
        log_result(record, category: :failed, message: "Failed to download PDF: #{e.message}")
      end
    ensure
      sleep(SLEEP_BETWEEN_REQUESTS)
    end
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
