# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  module PubmedIngest

    class PubmedIngestService
      attr_reader :attachment_results
      include Tasks::IngestHelper

      def initialize(config)
        raise ArgumentError, 'Missing required config keys' unless config['admin_set_title'] && config['depositor_onyen'] && config['attachment_results'] && config['start_date'] && config['end_date']

        @attachment_results = config['attachment_results'].symbolize_keys
        @start_date = config['start_date']
        @end_date = config['end_date']
        @output_dir = config['output_dir'] || Rails.root.join('tmp')
        @oa_fgci_start_date =  @start_date
        @oa_fgci_end_date = @end_date

        @admin_set = ::AdminSet.where(title: config['admin_set_title'])&.first
        raise ActiveRecord::RecordNotFound, "AdminSet not found with title: #{config['admin_set_title']}" unless @admin_set

        @depositor = User.find_by(uid: config['depositor_onyen'])
        raise ActiveRecord::RecordNotFound, "User not found with onyen: #{config['depositor_onyen']}" unless @depositor
        @record_ids = {
          'pubmed' => [],
          'pmc' => []
        }
        @record_ids_with_alternate_ids = {
          'pubmed' => [],
          'pmc' => []
        }
        @retrieved_metadata = []
        @pmc_oa_subset = []
      end

      # Keywords for readability
      def record_result(category:, file_name:, message:, ids: {}, article: nil)
        row = {
          'file_name' => file_name,
          'pdf_attached' => message,
          'pmid' => ids[:pmid],
          'pmcid' => ids[:pmcid],
          'doi' => ids[:doi],
        }

        if ids[:work_id]
          row['cdr_url'] = generate_cdr_url_for_existing_work(ids[:work_id])
        elsif article.present?
          row['cdr_url'] = generate_cdr_url_for_pubmed_identifier(row)
        end
        row['article'] = article if article
        @attachment_results[:counts][category] += 1

        @attachment_results[category] << row
      end


      def ingest_publications
        # # WIP: Working as intended - Start 
        # # Probably should retest - Start
        # # Hash array => { PMCID, Links to full-text OA content }
        @pmc_oa_subset = retrieve_oa_subset_within_date_range(@start_date, @end_date)
        write_test_results_to_json('tmp/test_pmc_oa_subset.json', @pmc_oa_subset)
        build_id_lists
        batch_retrieve_metadata
        # Retrieve additional OA subset resources to account for publication lag
        expand_pmc_oa_subset  
        write_test_results_to_json('tmp/test_pmc_oa_subset_expanded.json', @pmc_oa_subset)
        # # WIP: Working as intended - End
        # # Probably should retest - End
        # WIP: Testing - Start
        # @retrieved_metadata = process_xml_array_test_file('tmp/test_xml_arr.json')
        # write_test_results_to_json('tmp/test_results_j15.json', @retrieved_metadata)
        # expand_date_range_for_full_text_retrieval
        # write_test_results_to_json('tmp/test_results_j15_2.json', 
        #   { 
        #     original_start_date: @start_date.strftime('%Y-%m-%d'),
        #     original_end_date: @end_date.strftime('%Y-%m-%d'),
        #     oa_fgci_start_date: @oa_fgci_start_date.strftime('%Y-%m-%d'),
        #     oa_fgci_end_date: @oa_fgci_end_date.strftime('%Y-%m-%d')
        #   })

        # WIP: Testing - End

        # @pmc_oa_subset
        # Update these here now that :skipped is populated
        # @pmc_oa_subset = @attachment_results[:skipped].select { |row| row['pdf_attached'] == 'Skipped: No CDR URL' }
        # @attachment_results[:skipped] -= @pmc_oa_subset
        # @attachment_results[:counts][:skipped] -= @pmc_oa_subset.length

        # batch_retrieve_metadata
        # Rails.logger.info("[Ingest] Starting ingestion of #{@retrieved_metadata.size} records")

        # @retrieved_metadata.each_with_index do |metadata, index|
        #   Rails.logger.info("[Ingest] Processing record ##{index + 1}")
        #   begin
        #     article = new_article(metadata)
        #     builder = attribute_builder(metadata, article)
        #     skipped_row = builder.find_skipped_row(@pmc_oa_subset)

        #     Rails.logger.info("[Ingest] Found skipped row: #{skipped_row.inspect}")
        #     article.save!
        #     article.identifier.each { |id| Rails.logger.info("[Ingest] Article identifier: #{id}") }
        #     Rails.logger.info("[Ingest] Created new article with ID #{article.id}")

        #     attach_pdf(article, skipped_row)
        #     article.save!

        #     Rails.logger.info("[Ingest] Successfully attached PDF for article #{article.id}")
        #     skipped_row['cdr_url'] = generate_cdr_url_for_pubmed_identifier(skipped_row)
        #     skipped_row['article'] = article
        #     record_result(
        #       category: :successfully_ingested,
        #       file_name: skipped_row['file_name'],
        #       message: 'Success',
        #       ids: {
        #         pmid: skipped_row['pmid'],
        #         pmcid: skipped_row['pmcid'],
        #         doi: skipped_row['doi']
        #       },
        #       article: article
        #     )
        #   rescue => e
        #     doi = skipped_row&.[]('doi') || 'N/A'
        #     pmid = skipped_row&.[]('pmid') || 'N/A'
        #     pmcid = skipped_row&.[]('pmcid') || 'N/A'
        #     Rails.logger.error("[Ingest] Error processing record: DOI: #{doi}, PMID: #{pmid}, PMCID: #{pmcid}, Index: #{index}, Error: #{e.message}")
        #     Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
        #     article.destroy if article&.persisted?
        #     record_result(
        #       category: :failed,
        #       file_name: skipped_row['file_name'],
        #       message: "Failed: #{e.message}",
        #       ids: {
        #         pmid: skipped_row['pmid'],
        #         pmcid: skipped_row['pmcid'],
        #         doi: skipped_row['doi']
        #       }
        #     )
        #   end
        # end

        # Rails.logger.info('[Ingest] Ingest complete')
        # @attachment_results
      end

      def attach_pdf_for_existing_work(work_hash, file_path, depositor_onyen)
        begin
          # Create a work object using the provided work_hash
          model_class = work_hash[:work_type].constantize
          work = model_class.find(work_hash[:work_id])
          depositor =  User.find_by(uid: depositor_onyen)
          file = attach_pdf_to_work(work, file_path, depositor, Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
          admin_set = ::AdminSet.where(id: work_hash[:admin_set_id]).first
          file.update(permissions_attributes: group_permissions(admin_set))
          Rails.logger.info("[AttachPDFExisting] Successfully attached file for #{work_hash[:work_id]}")
          file
      rescue StandardError => e
        Rails.logger.error("[AttachPDFExisting] Error finding article for work ID #{work_hash[:work_id]}: #{e.message}")
        raise e
        end
      end

      private

      def process_xml_array_test_file(file_path)
        complete_xml_array = []
        message = "Processing test file: #{file_path}"
        puts message
        begin
          file_content = File.read(file_path)
          xml_array = JSON.parse(file_content)
          xml_documents = xml_array.map { |xml_str| Nokogiri::XML(xml_str) }
          complete_xml_array += xml_documents
          message = "Successfully read test file: #{file_path}"
          puts message
        rescue StandardError => e
          message = "Error parsing JSON from file #{file_path}: #{e.message}"
          puts message
          raise e
        end
        complete_xml_array
      end



      # Read test json file and process into hash
      def process_test_file(file_path)
        message = "Processing test file: #{file_path}"
        puts message
        begin
          file_content = File.read(file_path)
          test_data = JSON.parse(file_content)
          message = "Successfully read test file: #{file_path}"
          puts message
        rescue StandardError => e
          message = "Error parsing JSON from file #{file_path}: #{e.message}"
          puts message
          raise e
        end
        test_data
      end

      # Update the metadata storage with new metadata to avoid taking up too much memory
      def update_metadata_storage(file_path:, new_metadata:)
        @retrieved_metadata += new_metadata
        if @retrieved_metadata.size > 500
          Rails.logger.info("[PubmedIngestService - update_metadata_storage] Writing metadata to file: #{file_path}")
          append_results_to_stored_json_array(file_path, @retrieved_metadata)
          @retrieved_metadata = [] # Reset after writing
        end
      end

      def read_json(file_path)
        return nil unless File.exist?(file_path)
        begin
          file_content = File.read(file_path)
          parsed = JSON.parse(file_content)
        rescue StandardError => e
          Rails.logger.error("[PubmedIngestService - read_json] Error reading JSON file #{file_path}: #{e.message}")
          raise e
        end
        parsed
      end

      def append_results_to_stored_json_array(file_path, new_results)
        existing_results = read_json(file_path) || []
        combined_results = existing_results + new_results
        File.write(file_path, JSON.pretty_generate(combined_results))
      end

      def write_test_results_to_json(file_path, results)
        Rails.logger.info("Writing test results to JSON file: #{file_path}")
        begin
          File.write(file_path, JSON.pretty_generate(results))
          message = "Successfully wrote test results to JSON file: #{file_path}"
          puts message
        rescue StandardError => e
          message = "Error writing test results to JSON file #{file_path}: #{e.message}"
          puts message
          raise e
        end
      end

      # Adjust lists to remove duplicates and make the PubMed list PMID only
      def compare_and_adjust_id_lists
        # Iterate over a copy of the array to avoid mutation issues
        @record_ids_with_alternate_ids['pubmed'].dup.each do |alternate_id_hash|
          puts "Processing PubMed alternate ID: #{alternate_id_hash.inspect}"
          next if alternate_id_hash['pmcid'].blank?
           # Add hash to the PMC list if none of the PubMed hashes have the same PMCID
          if @record_ids_with_alternate_ids['pmc'].none? { |pmc_hash| pmc_hash['pmcid'] == alternate_id_hash['pmcid'] }
            @record_ids_with_alternate_ids['pmc'] << alternate_id_hash
          end
           # Remove the hash from the PubMed list
          @record_ids_with_alternate_ids['pubmed'].reject! do |pubmed_hash|
            pubmed_hash['pmcid'] == alternate_id_hash['pmcid']
          end
        end
      end

      def retrieve_alternate_ids_for_record_ids
        batched_ids = {
          'pubmed' => @record_ids['pubmed'].each_slice(200).to_a,
          'pmc' => @record_ids['pmc'].each_slice(200).to_a
        }

        Rails.logger.info("[PubmedIngestService - retrieve_alternate_ids_for_record_ids] Starting alternate ID retrieval for #{@record_ids['pmc'].size} PMC records split into #{batched_ids['pmc'].size} batches of 200")
        batched_ids['pmc'].each_with_index do |batch, index|
          Rails.logger.debug("[PubmedIngestService - retrieve_alternate_ids_for_record_ids] Processing PMC batch #{index + 1} of #{batched_ids['pmc'].size}")
          @record_ids_with_alternate_ids['pmc'] += retrieve_alternate_ids(batch)
        end

        Rails.logger.info("[PubmedIngestService - retrieve_alternate_ids_for_record_ids] Starting alternate ID retrieval for #{@record_ids['pubmed'].size} PubMed records split into #{batched_ids['pubmed'].size} batches of 200")
        batched_ids['pubmed'].each_with_index do |batch, index|
          Rails.logger.debug("[PubmedIngestService - retrieve_alternate_ids_for_record_ids] Processing PubMed batch #{index + 1} of #{batched_ids['pubmed'].size}")
          @record_ids_with_alternate_ids['pubmed'] += retrieve_alternate_ids(batch)
        end
        @record_ids_with_alternate_ids
      end

      def retrieve_alternate_ids(identifiers)
        begin
            # Use ID conversion API to resolve identifiers
          res = HTTParty.get("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=#{identifiers.join(',')}")
          doc = Nokogiri::XML(res.body)
          records = doc.xpath('//record').map do |record|
            if record['status'] == 'error'
              Rails.logger.debug("[IDConv] #{record['requested-id']} alternate IDs not found: #{record['errmsg']}")
              next
            end

            {
              'pmid' =>  record['pmid'],
              'pmcid' =>  record['pmcid'],
              'doi' => record['doi']
            }
          end.compact
        rescue StandardError => e
          Rails.logger.warn("[IDConv] HTTP failure for #{identifier}: #{e.message}")
          return fallback_id_hash(identifier)
        end
      end

      def fallback_id_hash(identifier)
        identifier.start_with?('PMC') ? { pmcid: identifier } : { pmid: identifier }
      end

      def expand_pmc_oa_subset(buffer = 2.years)
        Rails.logger.info("[PubmedIngestService - expand_pmc_oa_subset] Expanding PMC OA subset date range by #{buffer} to account for publication lag")
        extended_end_date = @oa_fgci_end_date + buffer
        Rails.logger.info("[PubmedIngestService - expand_pmc_oa_subset] New OA FGCI end date: #{extended_end_date.strftime('%Y-%m-%d')}")
        new_subset = retrieve_oa_subset_within_date_range(@oa_fgci_start_date, extended_end_date)
        Rails.logger.info("[PubmedIngestService - expand_pmc_oa_subset] Retrieved #{new_subset.size} additional OA records")
        @pmc_oa_subset += new_subset
        @pmc_oa_subset.uniq! { |record| record['pmcid'] }
        Rails.logger.info("[PubmedIngestService - expand_pmc_oa_subset] New total PMC OA subset size after expansion: #{@pmc_oa_subset.size}")
      end

      # Retrieve PMCIDs for works within the specified date range and links to their full-text OA content
      def retrieve_oa_subset_within_date_range(start_date = @start_date, end_date = @end_date)
        subset_array = []
        Rails.logger.info('[PubmedIngestService - retrieve_oa_subset] Starting OA metadata retrieval for PubMed works within the specified date range: ' \
                            "#{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}")
        base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi'
        current_url = "#{base_url}?from=#{start_date.strftime('%Y-%m-%d')}&until=#{end_date.strftime('%Y-%m-%d')}"
        loop do
          res = HTTParty.get(current_url)

          unless res.code == 200
            Rails.logger.error('[PubmedIngestService - retrieve_oa_subset] Failed to retrieve OA metadata: ' \
                                  "#{res.code} - #{res.message}")
            break
          end

          xml_doc = Nokogiri::XML(res.body)
          records = xml_doc.xpath('//record')
          subset_array += records.map do |record|
            {
              'pmcid' => record['id'],
              'links' => record.xpath('link').map do |link|
                           {
                             'format' => link['format'],
                             'href'   => link['href'],
                             'updated' => link['updated']
                             }
                         end
            }
          end

          Rails.logger.info("[PubmedIngestService - retrieve_oa_subset] Retrieved #{records.size} records from the current page")

            # Check for resumption token
          resumption_obj = xml_doc.at_xpath('//resumption/link')
          break unless resumption_obj

          next_href = resumption_obj['href']
          break unless next_href

          current_url = next_href
        end
        Rails.logger.info("[PubmedIngestService - retrieve_oa_subset] Completed OA metadata retrieval. Total records: #{subset_array.size}")
        subset_array
      end

      # The OA FCGI endpoint does not accept a list of PMCIDs as an argument, so use the retrieved metadata to determine a date range
      def expand_date_range_for_full_text_retrieval
        Rails.logger.info("[PubmedIngestService - expand_date_range_for_full_text_retrieval] Setting date range for full-text retrieval: #{@start_date.strftime('%Y-%m-%d')} to #{@end_date.strftime('%Y-%m-%d')}")
        @retrieved_metadata.each do |metadata|
          next if is_pubmed?(metadata)

          attribute_builder = PmcAttributeBuilder.new(metadata, nil, @admin_set, @depositor.uid)
          date_issued = attribute_builder.get_date_issued
          update_oa_fgci_date_range(date_issued)
        end

        # Provide a buffer of 2 years to account for lag between publication and full-text availability
        @oa_fgci_end_date += 2.years
      end

      def update_oa_fgci_date_range(date_issued)
        return unless date_issued.present?
        default_date = DateTime.new(0000, 1, 1) # Default date, set in get_date_issued within attribute builders

        if date_issued < @oa_fgci_start_date && date_issued > default_date
          @oa_fgci_start_date = date_issued
          Rails.logger.info("[PubmedIngestService - update_oa_fgci_date_range] Updated OA FGCI start date to: #{@oa_fgci_start_date}")
        end
        if date_issued > @oa_fgci_end_date
          @oa_fgci_end_date = date_issued
          Rails.logger.info("[PubmedIngestService - update_oa_fgci_date_range] Updated OA FGCI end date to: #{@oa_fgci_end_date}")
        end
      end


      def batch_retrieve_metadata
        md_size = @record_ids_with_alternate_ids['pubmed'].size + @record_ids_with_alternate_ids['pmc'].size
        Rails.logger.info("Starting metadata retrieval for #{md_size} records")

        works_with_pmids = @record_ids_with_alternate_ids['pubmed']
        works_with_pmcids = @record_ids_with_alternate_ids['pmc']

        [works_with_pmids, works_with_pmcids].each do |works|
          db = (works.equal?(works_with_pmids)) ? 'pubmed' : 'pmc'
          works.each_slice(100) do |batch|
            map_condition = (db == 'pubmed') ? 'pmid' : 'pmcid'
            ids = batch.map do |w|
              puts "Inspecting: #{w.inspect}"
              db == 'pubmed' ? w['pmid'] : w['pmcid'].delete_prefix('PMC')
            end
            request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{db}&id=#{ids.join(',')}&retmode=xml&tool=CDR&email=cdr@unc.edu"
            # WIP: Remove later
            message = "Fetching metadata for url: #{request_url}"
            Rails.logger.info(message)
            puts message
            res = HTTParty.get(request_url)

            if res.code != 200
              Rails.logger.error("Failed to fetch metadata for #{ids.join(', ')}: #{res.code} - #{res.message}")
              next
            end

            xml_doc = Nokogiri::XML(res.body)
            current_arr = xml_doc.xpath(db == 'pubmed' ? '//PubmedArticle' : '//article')
            update_metadata_storage(file_path: "#{@output_dir}/pubmed_ingest_md_intermediate_storage.json", new_metadata: current_arr)

            sleep(0.34) # Respect NCBI rate limits
          end
        end

        Rails.logger.info('Metadata retrieval complete')
        @retrieved_metadata
      end

      def new_article(metadata)
        Rails.logger.info('[Article] Initializing new article object')
        article = Article.new
        article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        builder = attribute_builder(metadata, article)
        builder.populate_article_metadata
      end

      def attach_pdf(article, skipped_row)
        Rails.logger.info("[AttachPDF] Attaching PDF for article #{article.id}")
        create_sipity_workflow(work: article)

        file_path =  Rails.root.join(@file_retrieval_directory, skipped_row['file_name'])
        Rails.logger.info("[AttachPDF] Resolved file path: #{file_path}")

        unless File.exist?(file_path)
          error_msg = "[AttachPDF] File not found at path: #{file_path}"
          Rails.logger.error(error_msg)
          raise StandardError, error_msg
        end

        pdf_file = attach_pdf_to_work(article, file_path, @depositor, article.visibility)

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

      def is_pubmed?(metadata)
        metadata.name == 'PubmedArticle'
      end

      def attribute_builder(metadata, article)
        is_pubmed?(metadata) ?
          PubmedAttributeBuilder.new(metadata, article, @admin_set, @depositor.uid) :
          PmcAttributeBuilder.new(metadata, article, @admin_set, @depositor.uid)
      end

      def generate_cdr_url_for_pubmed_identifier(skipped_row)
        identifier = skipped_row['pmcid'] || skipped_row['pmid']
        raise ArgumentError, 'No identifier (PMCID or PMID) found in row' unless identifier.present?

        result = Hyrax::SolrService.get("identifier_tesim:\"#{identifier}\"",
                              rows: 1,
                              fl: 'id,title_tesim,has_model_ssim,file_set_ids_ssim')['response']['docs']
        raise "No Solr record found for identifier: #{identifier}" if result.empty?

        record = result.first
        raise "Missing `has_model_ssim` in Solr record: #{record.inspect}" unless record['has_model_ssim']&.first.present?

        model = record['has_model_ssim']&.first&.underscore&.pluralize || 'works'
        URI.join(ENV['HYRAX_HOST'], "/concern/#{model}/#{record['id']}").to_s
      rescue => e
        Rails.logger.warn("[generate_cdr_url_for_pubmed_identifier] Failed for identifier: #{identifier}, error: #{e.message}")
        nil
      end

      def generate_cdr_url_for_existing_work(work_id)
        result = WorkUtilsHelper.fetch_work_data_by_id(work_id)
        raise "No work found with ID: #{work_id}" if result.nil?
        raise "Missing work_type for work with id: #{work_id}" unless result[:work_type].present?

        model = result[:work_type].underscore.pluralize
        URI.join(ENV['HYRAX_HOST'], "/concern/#{model}/#{work_id}").to_s
      rescue => e
        Rails.logger.warn("[generate_cdr_url_for_existing_work] Failed for work with id: #{work_id}, error: #{e.message}")
        nil
      end

      # Retrieve IDs from the esearch.fcgi, which only supports the pubmed db
      def retrieve_pubmed_ids_within_date_range(retmax = 1000)
        Rails.logger.info("[PubmedIngestService - retrieve_ids_within_date_range] Fetching IDs within date range: #{@start_date.strftime('%Y-%m-%d')} - #{@end_date.strftime('%Y-%m-%d')}")
        base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi'
        count = 0
        cursor = 0
        params = {
          retmax: retmax,
          db: 'pubmed',
          mindate: @start_date.strftime('%Y-%m-%d'),
          maxdate: @end_date.strftime('%Y-%m-%d')
        }
        loop do
          res = HTTParty.get(base_url, query: params.merge({ retstart: cursor}))
          if res.code != 200
            Rails.logger.error("[PubmedIngestService - retrieve_ids_within_date_range] Failed to retrieve IDs: #{res.code} - #{res.message}")
            break
          end
          parsed_response = Nokogiri::XML(res.body)
          add_to_pubmed_id_list(parsed_response)
          cursor += retmax
          break if cursor > parsed_response.xpath('//Count').text.to_i
        end
        Rails.logger.info("[PubmedIngestService - retrieve_ids_within_date_range] Retrieved #{@record_ids['pubmed'].size} IDs from pubmed database")
      end

      def build_id_lists
        Rails.logger.info("[PubmedIngestService - build_record_id_list] Starting to build record ID list")
        extract_pmc_ids_from_oa_subset
        retrieve_pubmed_ids_within_date_range
        # Expand record ID list to an array of hashes with alternate IDs
        retrieve_alternate_ids_for_record_ids
        # Check for duplicates among the pubmed and pmc lists and make the pubmed list PMID only
        compare_and_adjust_id_lists
      end


      def extract_pmc_ids_from_oa_subset
        Rails.logger.info("[PubmedIngestService - extract_pmc_ids_from_oa_subset] Starting PMC ID retrieval from OA subset of size #{@pmc_oa_subset.size}")
        @pmc_oa_subset.each do |record|
          pmcid = record['pmcid']
          next if pmcid.blank?
          @record_ids['pmc'] << pmcid
        end
        @record_ids['pmc'].uniq!
        Rails.logger.info("[PubmedIngestService - extract_pmc_ids_from_oa_subset] Retrieved #{@record_ids['pmc'].size} unique PMC IDs from OA subset")
      end

      def add_to_pubmed_id_list(parsed_response)
        ids = parsed_response.xpath('//IdList/Id').map(&:text)
        @record_ids['pubmed'].concat(ids)
      end
    end
  end
end
