# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService
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
    @pmc_id_path = File.join(@output_dir, 'pmc_ids.jsonl')
    @pubmed_id_path = File.join(@output_dir, 'pubmed_ids.jsonl')
    @pmc_alternate_ids_path = File.join(@output_dir, 'pmc_alternate_ids.jsonl')
    @pubmed_alternate_ids_path = File.join(@output_dir, 'pubmed_alternate_ids.jsonl')
    @oa_subset_path = File.join(@output_dir, 'oa_subset.jsonl')
    @oa_extended_path = File.join(@output_dir, 'oa_subset_extended.jsonl')
    @pmc_id_path = File.join(@output_dir, 'pmc_ids.jsonl')
    @pubmed_id_path = File.join(@output_dir, 'pubmed_ids.jsonl')
    @alternate_ids_path = File.join(@output_dir, 'alternate_ids.jsonl')
    @results_path = File.join(@output_dir, 'pubmed_ingest_results.jsonl')

  end

  def run
    # Working Section:
    # Create output directory using the date and time
    build_id_lists


    # WIP:
    # md_ingest_service = Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService.new(
    #   config: @config,
    #   results_tracker: @results
    # )
    # md_ingest_service.load_ids_from_file(path: File.join(@output_dir, 'pubmed_alternate_ids.jsonl'))
    # md_ingest_service.batch_retrieve_and_process_metadata(batch_size: 100, db: 'pubmed')
    # md_ingest_service.load_ids_from_file(path: File.join(@output_dir, 'pmc_alternate_ids.jsonl'))
    # md_ingest_service.batch_retrieve_and_process_metadata(batch_size: 100, db: 'pmc')
    # flat_results = flatten_result_hash(@results)
    # JsonlFileUtils.write_jsonl(flat_results, File.join(@output_dir, 'result_out_pmc.jsonl'), mode: 'w')
    # id_retrieval_service = Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService.new(
    #   start_date: @config['start_date'],
    #   end_date: @config['end_date']
    #   )
    # id_retrieval_service.retrieve_ids_within_date_range(path: @pubmed_id_path, db: 'pubmed')
    # id_retrieval_service.retrieve_ids_within_date_range(path: @pmc_id_path, db: 'pmc')

    # 1. Retrieve OA subset and write to JSONL file
    # oa_service = Tasks::PubmedIngest::Recurring::Utilities::OaSubsetService.new(start_date: @config['start_date'], end_date: @config['end_date'], output_path: @oa_subset_path)
    # oa_service.retrieve_oa_subset(start_date: @config['start_date'], end_date: @config['end_date'], output_path: @oa_subset_path)
    # Write OA subset to JSONL file
    # oa_service.expand_subset(buffer: 2.years, output_path: @oa_extended_path, current_day: @results[:time])


    # 2. Extract PMCIDs and write to file
    # pmc_ids = oa_service.extract_pmc_ids # returns array
    # write_json(pmc_id_path, pmc_ids)

    # # 3. Retrieve PubMed IDs from esearch and write to file
    # pubmed_ids = PubmedIdService.new(start_date, end_date).fetch_ids
    # write_json(pubmed_id_path, pubmed_ids)

    # # 4. Resolve alternate IDs for PMC + PubMed records
    # alternate_id_service = AlternateIdResolutionService.new(pmc_ids: pmc_ids, pubmed_ids: pubmed_ids)
    # record_id_hashes = alternate_id_service.resolve_all
    # write_json(alternate_ids_path, record_id_hashes)

    # # 4.5 Expand OA subset by a buffer (e.g., 2 years) to account for delays between OA publication and full text availability
    # oa_service.expand_subset(current_end_date: end_date, buffer: 2.years, output_file: oa_subset_path)
    # write_json(oa_subset_path, oa_service.extract_pmc_ids_from_file)

    # # 5. Ingest metadata in batches from EFetch
    # ingest_service = MetadataIngestService.new(record_ids: record_id_hashes, result_tracker: @results)
    # ingest_service.process_and_create_articles

    # # 6. Attach PDFs for known files in file_retrieval_directory
    # pdf_service = PdfAttachmentService.new(files_in_dir, record_id_hashes, result_tracker: @results)
    # pdf_service.attach_existing_works

    # # 7. Write results and notify
    # write_results_to_file
    # finalize_report_and_notify
  end

  private

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
      record_id_path = File.join(@output_dir, "#{db}_ids.jsonl")
      id_retrieval_service.retrieve_ids_within_date_range(output_path: record_id_path, db: db)
      @tracker['progress']['retrieve_ids_within_date_range'][db]['completed'] = true
      @tracker.save
    end

    ['pubmed', 'pmc'].each do |db|
      completed = @tracker['progress']['stream_and_write_alternate_ids'][db]['completed']
      if completed
        LogUtilsHelper.double_log("Skipping alternate ID retrieval for #{db} as it is already completed.", :info, tag: 'build_id_lists')
        next
      end
      record_id_path = File.join(@output_dir, "#{db}_ids.jsonl")
      LogUtilsHelper.double_log("Streaming and writing alternate IDs for the #{db} database.", :info, tag: 'build_id_lists')
      alternate_id_path = File.join(@output_dir, "#{db}_alternate_ids.jsonl")
      id_retrieval_service.stream_and_write_alternate_ids(input_path: record_id_path, output_path: alternate_id_path, db: db)
      @tracker['progress']['stream_and_write_alternate_ids'][db]['completed'] = true
      @tracker.save
    end

    LogUtilsHelper.double_log("ID lists built successfully. Output directory: #{@output_dir}", :info, tag: 'build_id_lists')
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
