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

  # def attach_pdf_to_work_with_binary(record, pdf_binary)
  #   article_id = record.dig('ids', 'article_id')
  #   return log_result(record, category: :skipped, message: 'No article ID found to attach PDF') unless article_id.present?

  #   article = Article.find(article_id)
  #   pmcid = record.dig('ids', 'pmcid')
  #   filename = generate_filename_for_work(article.id, pmcid)

  #   io = StringIO.new(pdf_binary)
  #   io.set_encoding('BINARY') if io.respond_to?(:set_encoding)
    
  #   log_result(record, category: :successfully_attached, message: 'PDF successfully attached.')
  # rescue => e
  #   log_result(record, category: :failed, message: "PDF attachment failed: #{e.message}")
  #   LogUtilsHelper.double_log("[FileAttachmentService] PDF attachment failed for #{article_id}: #{e.message}", :error, tag: 'Attachment')
  # end

  def attach_pdf_to_work_with_binary(record, pdf_binary)
    article_id = record.dig('ids', 'article_id')
    return log_result(record, category: :skipped, message: 'No article ID found to attach PDF') unless article_id.present?

    article = Article.find(article_id)
    pmcid = record.dig('ids', 'pmcid')
    depositor = ::User.find_by(uid: 'admin')
    raise "No depositor found" unless depositor

    filename = generate_filename_for_work(article.id, pmcid)
    file_path = File.join(@full_text_path, filename)
    File.binwrite(file_path, pdf_binary)
    FileUtils.chmod(0o644, file_path)

    begin

      file_set = FileSet.create(
        visibility: article.visibility,
        label: filename,
        title: [filename],
        depositor: depositor.user_key
      )

      wrapper = JobIoWrapper.create!(
        user: depositor,
        file_set_id: file_set.id,
        path: file_path,                    # <-- no Tempfile!
        relation: 'original_file',
        mime_type: 'application/pdf',
        original_name: filename
      )

      Rails.logger.info("Checking file exists at: #{file_path} => #{File.exist?(file_path)}")
      IngestJob.perform_now(wrapper)
      Rails.logger.info("After IngestJob, file still exists at: #{file_path} => #{File.exist?(file_path)}")

      file_set.reload
      file_set.original_file&.reload
      file_set.update_index

      actor = Hyrax::Actors::FileSetActor.new(file_set, depositor)
      actor.attach_to_work(article)

      file_set.permissions_attributes = group_permissions(article.admin_set)
      file_set.save!

      article.reload
      article.representative_id ||= file_set.id
      article.thumbnail_id ||= file_set.id
      article.rendering_ids << file_set.id.to_s unless article.rendering_ids.include?(file_set.id.to_s)
      article.save!
      article.update_index

      # Wait for original_file to attach (max 5s)
      max_wait = 10
      waited = 0
      until file_set.reload.original_file.present? || waited >= max_wait
        sleep 0.5
        waited += 0.5
      end


      if file_set.original_file&.id
        CreateDerivativesJob.perform_later(file_set, file_set.original_file.id)
      else
        Rails.logger.warn("Original file still nil for FileSet #{file_set.id}")
      end

      log_result(record, category: :successfully_attached, message: 'PDF successfully attached.')
      return file_set
    rescue => e
      log_result(record, category: :failed, message: "PDF attachment failed: #{e.message}")
      LogUtilsHelper.double_log("[FileAttachmentService] PDF attachment failed for #{article_id}: #{e.message}", :error, tag: 'Attachment')
      raise
    end
  end

  def safe_gzip_reader(path)
    content = File.binread(path)
    gzip_start = content.index("\x1F\x8B".b)
    raise "No GZIP header found in file" unless gzip_start

    str_io = StringIO.new(content[gzip_start..])
    Zlib::GzipReader.new(str_io)
  end


  def process_and_attach_tgz_file(record, tgz_binary)
    pmcid = record.dig('ids', 'pmcid')
    article_id = record.dig('ids', 'article_id')
    return log_result(record, category: :skipped, message: 'No article ID found to attach TGZ') unless article_id.present?

    begin
      work = Article.find(article_id)
      depositor = ::User.find_by(uid: 'admin')
      raise "No depositor found" unless depositor

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
          file_set = attach_pdf_to_work_with_binary(record, pdf_binary)
          if file_set
            attached_files << entry.full_name
            pdf_count += 1
          end
        end
      end
      gz.close

      # Clean up the temporary TGZ file
      File.delete(tgz_absolute_path) if File.exist?(tgz_absolute_path)

      if pdf_count == 0
        raise "No PDF files found in TGZ archive"
      end

      work.reload
      work.update_index

      log_result(record, category: :successfully_attached, message: "Extracted and attached #{pdf_count} PDFs from TGZ: #{attached_files.join(', ')}")

    rescue => e
      log_result(record, category: :failed, message: "TGZ PDF processing failed: #{e.message}")
      Rails.logger.error "TGZ PDF processing failed for #{pmcid}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end


  def attach_pdf_to_work_with_binary(record, pdf_binary)
  article_id = record.dig('ids', 'article_id')
  return log_result(record, category: :skipped, message: 'No article ID found to attach PDF') unless article_id.present?

  article = Article.find(article_id)
  pmcid = record.dig('ids', 'pmcid')
  depositor = ::User.find_by(uid: 'admin')
  raise "No depositor found" unless depositor

  filename = generate_filename_for_work(article.id, pmcid)

  begin
    # Create FileSet first
    file_set = FileSet.create(
      visibility: article.visibility,
      label: filename,
      title: [filename],
      depositor: depositor.user_key
    )

    Rails.logger.info("Created FileSet #{file_set.id} for article #{article_id}")

    # Create actor
    actor = Hyrax::Actors::FileSetActor.new(file_set, depositor)

    # Create metadata
    file_set_params = { 
      visibility: article.visibility,
      title: [filename],
      label: filename
    }
    
    Rails.logger.info("Creating metadata for FileSet #{file_set.id}")
    actor.create_metadata(file_set_params)

    # Create a proper uploaded file object that mimics what Hyrax expects
    uploaded_file = create_uploaded_file_from_binary(pdf_binary, filename)
    
    Rails.logger.info("Creating content for FileSet #{file_set.id} with uploaded file")
    
    # Use create_content with the uploaded file
    uploaded_file.tempfile.rewind
    actor.create_content(uploaded_file)

    # Wait for original file to be created
    max_attempts = 30
    attempt = 0
    
    while attempt < max_attempts
      file_set.reload
      if file_set.original_file.present?
        Rails.logger.info("Original file attached successfully: #{file_set.original_file.id}")
        break
      end
      
      attempt += 1
      Rails.logger.info("Waiting for original_file... attempt #{attempt}/#{max_attempts}")
      sleep(1)
    end

    if file_set.original_file.blank?
      raise "Original file failed to attach after #{max_attempts} attempts"
    end

    # Attach to work
    Rails.logger.info("Attaching FileSet #{file_set.id} to Work #{article.id}")
    actor.attach_to_work(article)

    # Set permissions
    file_set.permissions_attributes = group_permissions(article.admin_set)
    file_set.save!

    # Update work relationships
    article.reload
    article.representative_id ||= file_set.id
    article.thumbnail_id ||= file_set.id
    unless article.rendering_ids.include?(file_set.id.to_s)
      article.rendering_ids += [file_set.id.to_s]
    end
    article.save!

    # Reindex both objects
    file_set.update_index
    article.update_index

    # Create derivatives using the uploaded file path
    Rails.logger.info("Creating derivatives for FileSet #{file_set.id}")
    CreateDerivativesJob.perform_now(file_set, file_set.original_file.id, uploaded_file.path)

    # Final reindex after derivatives
    sleep(2) # Give derivatives time to complete
    file_set.reload
    file_set.update_index
    article.reload  
    article.update_index

    Rails.logger.info("Successfully attached PDF to FileSet #{file_set.id}")
    log_result(record, category: :successfully_attached, message: 'PDF successfully attached with derivatives.')
    
    return file_set
    
  rescue => e
    Rails.logger.error "PDF attachment failed for #{article_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.backtrace
    log_result(record, category: :failed, message: "PDF attachment failed: #{e.message}")
    raise
  ensure
    # Cleanup uploaded file if it exists
    if defined?(uploaded_file) && uploaded_file&.respond_to?(:path) && uploaded_file.path && File.exist?(uploaded_file.path)
      File.unlink(uploaded_file.path) rescue nil
    end
  end
end


def create_uploaded_file_from_binary(binary_data, filename)
    # Create a temporary file in the uploads directory
    upload_dir = File.join(Rails.root, 'tmp', 'uploads')
    FileUtils.mkdir_p(upload_dir)
    
    temp_path = File.join(upload_dir, "#{SecureRandom.uuid}_#{filename}")
    
    # Write binary data to temp file
    File.binwrite(temp_path, binary_data)
    FileUtils.chmod(0o644, temp_path)
    
    Rails.logger.info("Created temporary file at #{temp_path} (#{binary_data.bytesize} bytes)")
    
    # Create an object that behaves like an uploaded file
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(temp_path, 'rb'),
      filename: filename,
      type: 'application/pdf',
      head: "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\nContent-Type: application/pdf\r\n"
    )
    
    # Add path method for cleanup
    uploaded_file.define_singleton_method(:path) { temp_path }
    
    uploaded_file
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