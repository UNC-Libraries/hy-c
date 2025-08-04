# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService
  BUILD_ID_LISTS_DIR = '01_build_id_lists'
  LOAD_METADATA_DIR  = '02_load_and_ingest_metadata'
  ATTACH_FILES_DIR    = '03_attach_files_to_works'
  def initialize(config, tracker)
    @config = config
    @tracker = tracker
    # @file_retrieval_directory = config['file_retrieval_directory']
    # @files_in_dir = retrieve_filenames(@config['file_retrieval_directory'])
    @depositor_onyen = config['depositor_onyen']
    @results = {
      skipped: [],
      successfully_attached: [],
      successfully_ingested: [],
      failed: [],
      time: Time.now,
      depositor: config['depositor_onyen'],
      output_dir: config['output_dir'],
      admin_set: config['admin_set_title'],
      counts: {
        skipped: 0,
        successfully_attached: 0,
        successfully_ingested: 0,
        failed: 0
      }
    }
    # WIP: Hardcode time for testing purposes
    # @results[:time] = Time.parse('2023-10-01 12:00:00')
    # timestamp = @results[:time].strftime('pubmed_ingest_%Y-%m-%d_%H-%M-%S')
    @output_dir = config['output_dir']
    # FileUtils.mkdir_p(@output_dir)
    # @pmc_id_path = File.join(@output_dir, 'pmc_ids.jsonl')
    # @pubmed_id_path = File.join(@output_dir, 'pubmed_ids.jsonl')
    # @pmc_alternate_ids_path = File.join(@output_dir, 'pmc_alternate_ids.jsonl')
    # @pubmed_alternate_ids_path = File.join(@output_dir, 'pubmed_alternate_ids.jsonl')
    # @oa_subset_path = File.join(@output_dir, 'oa_subset.jsonl')
    # @oa_extended_path = File.join(@output_dir, 'oa_subset_extended.jsonl')
    # @pmc_id_path = File.join(@output_dir, 'pmc_ids.jsonl')
    # @pubmed_id_path = File.join(@output_dir, 'pubmed_ids.jsonl')
    # @alternate_ids_path = File.join(@output_dir, 'alternate_ids.jsonl')
    # @results_path = File.join(@output_dir, 'pubmed_ingest_results.jsonl')


    @id_list_output_directory = File.join(@output_dir, BUILD_ID_LISTS_DIR)
    @metadata_ingest_output_directory = File.join(@output_dir, LOAD_METADATA_DIR)

  end

  def run
    # Working Section:
    # Create output directory using the date and time
    build_id_lists
    load_and_ingest_metadata
    # WIP:
    attach_files
    # write_results_to_file
    # finalize_report_and_notify
  end

  private

  def attach_files
    file_attachment_service = Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService.new(
      config: @config,
      tracker: @tracker,
      output_path: File.join(@output_dir, ATTACH_FILES_DIR),
      full_text_path: @config['full_text_dir'],
      metadata_ingest_result_path: File.join(@metadata_ingest_output_directory, 'metadata_ingest_results.jsonl'),
    )
    file_attachment_service.run
  end

  def flatten_result_hash(results)
    flat = []
    results.each do |category, value|
      next unless [:skipped, :successfully_attached, :successfully_ingested, :failed].include?(category)
      Array(value).each do |record|
        flat << record.merge('category' => category.to_s)
      end
    end
    flat
  end

  def load_and_ingest_metadata
    md_ingest_service = Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService.new(
      config: @config,
      results: @results,
      tracker: @tracker,
      results_path: File.join(@metadata_ingest_output_directory, 'metadata_ingest_results.jsonl'),
    )
    ['pubmed', 'pmc'].each do |db|
      if @tracker['progress']['metadata_ingest'][db]['completed']
        LogUtilsHelper.double_log("Skipping metadata ingest for #{db} as it is already completed.", :info, tag: 'load_and_ingest_metadata')
        next
      end
      md_ingest_service.load_alternate_ids_from_file(path: File.join(@id_list_output_directory, "#{db}_alternate_ids.jsonl"))
      # WIP: Temporarily limit number of batches for testing
      md_ingest_service.batch_retrieve_and_process_metadata(batch_size: 3, db: db)
      @tracker['progress']['metadata_ingest'][db]['completed'] = true
      @tracker.save
      LogUtilsHelper.double_log("Metadata ingest for #{db} completed successfully.", :info, tag: 'load_and_ingest_metadata')
      LogUtilsHelper.double_log("Output directory: #{@metadata_ingest_output_directory}", :info, tag: 'load_and_ingest_metadata')
    end
  end

  def load_previously_saved_results
    if File.exist?(@results_path)
      LogUtilsHelper.double_log("Loading previously saved results from #{@results_path}", :info, tag: 'load_previously_saved_results')
      begin
        content = File.read(@results_path, encoding: 'utf-8')
        @results = JSON.parse(content).deep_symbolize_keys
        LogUtilsHelper.double_log("Successfully loaded results. Current counts: #{@results['counts']}", :info, tag: 'load_previously_saved_results')
      rescue => e
        LogUtilsHelper.double_log("Failed to load results from #{@results_path}: #{e.message}", :error, tag: 'load_previously_saved_results')
      end
    else
      LogUtilsHelper.double_log("No previous results found at #{@results_path}. Starting fresh.", :info, tag: 'load_previously_saved_results')
    end
  end

  def build_id_lists
    id_retrieval_service = Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService.new(
      start_date: @config['start_date'],
      end_date: @config['end_date'],
      tracker: @tracker
    )
    ['pubmed', 'pmc'].each do |db|
      completed = @tracker['progress']['retrieve_ids_within_date_range'][db]['completed']
      if completed
        LogUtilsHelper.double_log("Skipping ID retrieval for #{db} as it is already completed.", :info, tag: 'build_id_lists')
        next
      end

      LogUtilsHelper.double_log("Retrieving record IDs for PubMed and PMC databases within the date range: #{@config['start_date'].strftime('%Y-%m-%d')} - #{@config['end_date'].strftime('%Y-%m-%d')}", :info, tag: 'build_id_lists')
      record_id_path = File.join(@id_list_output_directory, "#{db}_ids.jsonl")
      # WIP: Temporarily limit the number of records retrieved for testing
      id_retrieval_service.retrieve_ids_within_date_range(output_path: record_id_path, db: db, retmax: 5)
      @tracker['progress']['retrieve_ids_within_date_range'][db]['completed'] = true
      @tracker.save
    end

    ['pubmed', 'pmc'].each do |db|
      completed = @tracker['progress']['stream_and_write_alternate_ids'][db]['completed']
      if completed
        LogUtilsHelper.double_log("Skipping alternate ID retrieval for #{db} as it is already completed.", :info, tag: 'build_id_lists')
        next
      end
      record_id_path = File.join(@id_list_output_directory, "#{db}_ids.jsonl")
      LogUtilsHelper.double_log("Streaming and writing alternate IDs for the #{db} database.", :info, tag: 'build_id_lists')
      alternate_id_path = File.join(@id_list_output_directory, "#{db}_alternate_ids.jsonl")
      id_retrieval_service.stream_and_write_alternate_ids(input_path: record_id_path, output_path: alternate_id_path, db: db)
      @tracker['progress']['stream_and_write_alternate_ids'][db]['completed'] = true
      @tracker.save
    end

    id_retrieval_service.adjust_id_lists(
      pubmed_path: File.join(@id_list_output_directory, 'pubmed_alternate_ids.jsonl'),
      pmc_path: File.join(@id_list_output_directory, 'pmc_alternate_ids.jsonl')
    )
    LogUtilsHelper.double_log("ID lists built successfully. Output directory: #{@id_list_output_directory}", :info, tag: 'build_id_lists')
  end

  def process_file_matches
    encountered_alternate_ids = []

    @files_in_dir.each do |file_name, file_ext|
      begin
        alternate_ids = retrieve_alternate_ids(file_name)

        unless alternate_ids
          double_log("No alternate IDs found for #{full_file_name(file_name, file_ext)}", :warn)
          @pubmed_ingest_service.record_result(
            category: :failed,
            file_name: full_file_name(file_name, file_ext),
            message: 'Failed: No alternate IDs',
            ids: {}
          )
          next
        end

        # In case a PMID and PMCID point to the same work, we only want to process it once
        if encountered_alternate_ids.any? { |ids| has_matching_ids?(ids, alternate_ids) }
          log_and_label_skip(file_name, file_ext, alternate_ids, 'Already encountered this work during current run. Identifiers: ' + alternate_ids.to_s)
          next
        else
          encountered_alternate_ids << alternate_ids
        end

        match = find_best_work_match(alternate_ids)

        if match&.dig(:file_set_ids).present?
          # Attach work id to generate URL for existing work (PubmedIngestService::PubmedIngest::record_result)
          alternate_ids[:work_id] = match[:work_id]
          log_and_label_skip(file_name, file_ext, alternate_ids, 'File already attached to work')
        elsif match&.dig(:work_id).present?
          double_log("Found existing work for #{file_name}: #{match[:work_id]} with no fileset. Attempting to attach PDF.")
          path = File.join(@config['file_retrieval_directory'], full_file_name(file_name, file_ext))
          @pubmed_ingest_service.attach_pdf_for_existing_work(match, path, @depositor_onyen)
          @pubmed_ingest_service.record_result(
            category: :successfully_attached,
            file_name: full_file_name(file_name, file_ext),
            message: 'Success',
            ids: alternate_ids,
            article: WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
          )
        else
          double_log("No match found — will be ingested: #{full_file_name(file_name, file_ext)}", :warn)
          @pubmed_ingest_service.record_result(
            category: :skipped,
            file_name: full_file_name(file_name, file_ext),
            message: 'Skipped: No CDR URL',
            ids: alternate_ids
          )
        end
      rescue StandardError => e
        double_log("Error processing file #{file_name}: #{e.message}", :error)
        @pubmed_ingest_service.record_result(
          category: :failed,
          file_name: full_file_name(file_name, file_ext),
          message: "Failed: #{e.message}",
          ids: alternate_ids
        )
        next
      end
    end

    double_log("Processing complete. Results: #{@pubmed_ingest_service.attachment_results[:counts]}")
  end

  def attach_remaining_pdfs
    if @pubmed_ingest_service.attachment_results[:skipped].empty?
      double_log('No skipped items to ingest', :info)
      return
    end
    double_log('Attaching PDFs for skipped records...', :info)

    begin
      ingest_results = @pubmed_ingest_service.ingest_publications
      double_log("Finished ingesting skipped PDFs. Counts: #{ingest_results[:counts]}")
    rescue => e
      double_log("Error during PDF ingestion: #{e.message}", :error)
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    end
  end

  def write_results_to_file
    json_output_path = Rails.root.join(@output_dir, "pdf_attachment_results_#{@pubmed_ingest_service.attachment_results[:time].strftime('%Y%m%d%H%M%S')}.json")
    File.open(json_output_path, 'w') { |f| f.write(JSON.pretty_generate(@pubmed_ingest_service.attachment_results)) }

    double_log("Results written to #{json_output_path}", :info)
    double_log("Ingested: #{@pubmed_ingest_service.attachment_results[:successfully_ingested].length}, Attached: #{@pubmed_ingest_service.attachment_results[:successfully_attached].length}, Failed: #{@pubmed_ingest_service.attachment_results[:failed].length}, Skipped: #{@pubmed_ingest_service.attachment_results[:skipped].length}", :info)
  end

  def finalize_report_and_notify
    # Generate report, log, send email
    double_log('Sending email with results', :info)
    begin
      report = Tasks::PubmedIngest::SharedUtilities::PubmedReportingService.generate_report(@pubmed_ingest_service.attachment_results)
      PubmedReportMailer.pubmed_report_email(report).deliver_now
      double_log('Email sent successfully', :info)
    rescue StandardError => e
      double_log("Failed to send email: #{e.message}", :error)
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    end
  end

      # Helper methods

  def find_best_work_match(alternate_ids)
    [:doi, :pmcid, :pmid].each do |key|
      id = alternate_ids[key]
      next if id.blank?

      work_data = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id)
      return work_data if work_data.present?
    end
    nil
  end

  def retrieve_alternate_ids(identifier)
    begin
        # Use ID conversion API to resolve identifiers
      res = HTTParty.get("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=#{identifier}")
      doc = Nokogiri::XML(res.body)
      record = doc.at_xpath('//record')
      if record.blank? || record['status'] == 'error'
        Rails.logger.warn("[IDConv] Fallback used for identifier: #{identifier}")
        return fallback_id_hash(identifier)
      end

      {
      pmid:  record['pmid'],
      pmcid: record['pmcid'],
      doi:   record['doi']
      }
  rescue StandardError => e
    Rails.logger.warn("[IDConv] HTTP failure for #{identifier}: #{e.message}")
    return fallback_id_hash(identifier)
    end
  end

  def double_log(msg, level = :info)
    tagged = "[Coordinator] #{msg}"
    puts tagged
    case level
    when :warn then Rails.logger.warn(tagged)
    when :error then Rails.logger.error(tagged)
    else Rails.logger.info(tagged)
    end
  end

  def retrieve_filenames(directory)
    abs_path = Pathname.new(directory).absolute? ? directory : Rails.root.join(directory)
    Dir.entries(abs_path)
      .select { |f| !File.directory?(File.join(abs_path, f)) }
      .reject { |f|  ['.', '..'].include?(f) } # Exclude hidden files
      .sort
      .map { |f| [File.basename(f, '.*'), File.extname(f).delete('.')] }
      .uniq
  end

  def log_and_label_skip(file_name, file_ext, alternate_ids, reason)
    full_name = full_file_name(file_name, file_ext)
    double_log("⏭️  #{full_name} - #{reason}", :info)
    @pubmed_ingest_service.record_result(
        category: :skipped,
        file_name: full_file_name(file_name, file_ext),
        message: reason,
        ids: alternate_ids
    )
  end

  def has_matching_ids?(existing, current)
    [:pmid, :pmcid, :doi].any? { |k| existing[k] == current[k] }
  end

  def fallback_id_hash(identifier)
    identifier.start_with?('PMC') ? { pmcid: identifier } : { pmid: identifier }
  end

  def full_file_name(name, ext)
    "#{name}.#{ext}"
  end
end
