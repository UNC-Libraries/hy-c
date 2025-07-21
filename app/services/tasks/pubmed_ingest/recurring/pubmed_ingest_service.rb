# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  module PubmedIngest
    module Recurring

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

        def ingest_publications
          # WIP: Should probably remove works that already exist in the cdr
          # WIP: Don't need to check for filesets, attach_pdf_for_existing_work will handle that (maybe)
          # # WIP: Working as intended - Start
          # # Hash array => { PMCID, Links to full-text OA content }
          # retrieve_oa_subset_within_date_range(@start_date, @end_date)
          # write_to_json('tmp/test_pmc_oa_subset.json', @pmc_oa_subset)
          # build_id_lists
          # write_to_json("#{@output_dir}/pubmed_ingest_alternate_id_list.json", @record_ids_with_alternate_ids)
          # expand_pmc_oa_subset
          # batch_retrieve_and_process_metadata
          # Retrieve additional OA subset resources to account for publication lag
          # # WIP: Working as intended - End
          # WIP: Testing - Start
          # WIP: Dont have to retrieve OA subset, just build the ID lists. It's already been retrieved
          build_id_lists
          write_to_json("#{@output_dir}/pubmed_ingest_alternate_id_list.json", @record_ids_with_alternate_ids)
          puts 'Built id lists for PMC and PubMed'
          expand_pmc_oa_subset
          batch_retrieve_and_process_metadata
          # WIP: Testing - End
        end

        private

        # Retrieve metadata for PubMed and PMC works in batches and process them inline
        def batch_retrieve_and_process_metadata(batch_size = 100)
          total_records = @record_ids_with_alternate_ids['pubmed'].size + @record_ids_with_alternate_ids['pmc'].size
          Rails.logger.info("Starting metadata retrieval and processing for #{total_records} records")

          works_with_pmids = @record_ids_with_alternate_ids['pubmed']
          works_with_pmcids = @record_ids_with_alternate_ids['pmc']

          [works_with_pmcids, works_with_pmids].each do |works|
            db = (works.equal?(works_with_pmids)) ? 'pmc' : 'pubmed'
            works.each_slice(batch_size) do |batch|
              ids = batch.map { |w| db == 'pubmed' ? w['pmid'] : w['pmcid'].delete_prefix('PMC') }
              request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{db}&id=#{ids.join(',')}&retmode=xml&tool=CDR&email=cdr@unc.edu"

              Rails.logger.info("Fetching metadata for IDs: #{ids.join(', ')}")
              res = HTTParty.get(request_url)

              if res.code != 200
                Rails.logger.error("Failed to fetch metadata for #{ids.join(', ')}: #{res.code} - #{res.message}")
                next
              end

              xml_doc = Nokogiri::XML(res.body)

              # Handle PMC errors if needed
              handle_pmc_errors(xml_doc, ids) if db == 'pmc' && xml_doc.xpath('//pmc-articleset/error').any?

              # Process the batch immediately
              current_batch = xml_doc.xpath(db == 'pubmed' ? '//PubmedArticle' : '//article')
              process_batch(current_batch)

              sleep(0.34) # Respect NCBI rate limits
              # WIP: End after the first batch for testing
              break
            end
          end

          Rails.logger.info('Metadata retrieval and processing complete')
        end

        def process_batch(batch)
          batch.each do |doc|
            alternate_ids = {
              'pmid' => nil,
              'pmcid' => nil,
              'doi' => nil
            }
            begin
              article = new_article(doc)
              alternate_ids = alternate_ids_from_xml(doc, article)

              Rails.logger.info("[Ingest] Found alternate_ids row: #{alternate_ids.inspect}")
              article.save!
              article.identifier.each { |id| Rails.logger.info("[Ingest] Article identifier: #{id}") }
              Rails.logger.info("[Ingest] Created new article with ID #{article.id}")

              # WIP: Skip PDF attachment for now, add as post processing step
              # attach_pdf(article, skipped_row)
              # article.save!

              # Rails.logger.info("[Ingest] Successfully attached PDF for article #{article.id}")
              # skipped_row['cdr_url'] = generate_cdr_url_for_pubmed_identifier(skipped_row)
              if alternate_ids.present?
                alternate_ids['article'] = article
              end

              record_result(
                category: :successfully_ingested,
                # WIP: Placeholder for file_name
                file_name: '',
                message: 'Success',
                ids: {
                  pmid: alternate_ids&.[]('pmid'),
                  pmcid: alternate_ids&.[]('pmcid'),
                  doi: alternate_ids&.[]('doi')
                },
                article: article
              )
            rescue => e
              doi = alternate_ids&.[]('doi') || 'N/A'
              pmid = alternate_ids&.[]('pmid') || 'N/A'
              pmcid = alternate_ids&.[]('pmcid') || 'N/A'
              Rails.logger.error("[Ingest] Error processing record: DOI: #{doi}, PMID: #{pmid}, PMCID: #{pmcid}, Error: #{e.message}")
              Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
              article.destroy if article&.persisted?
              record_result(
                category: :failed,
                # file_name: alternate_ids['file_name'],
                message: "Failed: #{e.message}",
                ids: {
                  pmid: alternate_ids['pmid'],
                  pmcid: alternate_ids['pmcid'],
                  doi: alternate_ids['doi']
                }
              )
            end
          end
        end

        def build_id_lists
          Rails.logger.info('[PubmedIngestService - build_record_id_list] Starting to build record ID list')
          extract_pmc_ids_from_oa_subset
          retrieve_pubmed_ids_within_date_range
          # Expand record ID list to an array of hashes with alternate IDs
          retrieve_alternate_ids_for_record_ids
          # Check for duplicates among the pubmed and pmc lists and make the pubmed list PMID only
          compare_and_adjust_id_lists
          Rails.logger.info('[PubmedIngestService - build_record_id_list] Completed building record ID list')
        end


        def extract_pmc_ids_from_oa_subset(input_file = "#{@output_dir}/oa_subset.jsonl")
          Rails.logger.info("[PubmedIngestService - extract_pmc_ids_from_oa_subset] Extracting PMC IDs from OA subset file: #{input_file}")

          pmc_ids = []

          File.foreach(input_file) do |line|
            record = JSON.parse(line)
            pmcid = record['pmcid']
            next if pmcid.blank?
            pmc_ids << pmcid
          end

          @record_ids['pmc'] = pmc_ids.uniq

          Rails.logger.info("[PubmedIngestService - extract_pmc_ids_from_oa_subset] Retrieved #{@record_ids['pmc'].size} unique PMC IDs from OA subset file")
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

              # Adjust lists to remove duplicates and make the PubMed list PMID only
        def compare_and_adjust_id_lists
          # Iterate over a copy of the array to avoid mutation issues
          @record_ids_with_alternate_ids['pubmed'].dup.each do |alternate_id_hash|
            # puts "Processing PubMed alternate ID: #{alternate_id_hash.inspect}"
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
            @record_ids_with_alternate_ids['pmc'] += retrieve_alternate_ids(batch, 'pmc')
          end

          Rails.logger.info("[PubmedIngestService - retrieve_alternate_ids_for_record_ids] Starting alternate ID retrieval for #{@record_ids['pubmed'].size} PubMed records split into #{batched_ids['pubmed'].size} batches of 200")
          batched_ids['pubmed'].each_with_index do |batch, index|
            Rails.logger.debug("[PubmedIngestService - retrieve_alternate_ids_for_record_ids] Processing PubMed batch #{index + 1} of #{batched_ids['pubmed'].size}")
            @record_ids_with_alternate_ids['pubmed'] += retrieve_alternate_ids(batch, 'pubmed')
          end
          @record_ids_with_alternate_ids
        end

        def retrieve_alternate_ids(identifiers, db)
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
                'doi' => record['doi'],
                'cdr_url' => generate_cdr_url_for_pubmed_identifier({'pmid' => record['pmid'], 'pmcid' => record['pmcid']})
              }
            end.compact
          rescue StandardError => e
            Rails.logger.warn("[IDConv] HTTP failure for #{identifier}: #{e.message}")
            return fallback_id_hash(identifier)
          end
        end

        def expand_pmc_oa_subset(buffer = 2.years)
          extended_range = {
            'start_date' => @oa_fgci_end_date + 1.day,
            'end_date' => @oa_fgci_end_date + buffer
          }
          Rails.logger.info('[PubmedIngestService - expand_pmc_oa_subset] Recovering additional OA records to account for publication lag.')
          Rails.logger.info("[PubmedIngestService - expand_pmc_oa_subset] Search range: #{extended_range['start_date'].strftime('%Y-%m-%d')} to #{extended_range['end_date'].strftime('%Y-%m-%d')}")
        # Write the extended subset to a separate file
          new_subset = retrieve_oa_subset_within_date_range(extended_range['start_date'], extended_range['end_date'], "#{@output_dir}/oa_subset_expanded.jsonl")
          Rails.logger.info("[PubmedIngestService - expand_pmc_oa_subset] OA Subset expanded by #{new_subset.size} records.")
        end

        # Retrieve PMCIDs for works within the specified date range and links to their full-text OA content
        def retrieve_oa_subset_within_date_range(start_date = @start_date, end_date = @end_date, output_file = "#{@output_dir}/oa_subset.jsonl")
          Rails.logger.info("[PubmedIngestService - retrieve_oa_subset] Starting OA metadata retrieval for PubMed works between #{start_date.strftime('%Y-%m-%d')} and #{end_date.strftime('%Y-%m-%d')}")

          base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi'
          current_url = "#{base_url}?from=#{start_date.strftime('%Y-%m-%d')}&until=#{end_date.strftime('%Y-%m-%d')}"

          File.open(output_file, 'a') do |file|
            loop do
              res = HTTParty.get(current_url)

              unless res.code == 200
                Rails.logger.error("[PubmedIngestService - retrieve_oa_subset] Failed to retrieve OA metadata: #{res.code} - #{res.message}")
                break
              end

              xml_doc = Nokogiri::XML(res.body)
              records = xml_doc.xpath('//record')

              records.each do |record|
                record_hash = {
                  'pmcid' => record['id'],
                  'links' => record.xpath('link').map do |link|
                               {
                                 'format' => link['format'],
                                 'href'   => link['href'],
                                 'updated' => link['updated']
                               }
                             end
                }
                file.puts(record_hash.to_json)
              end

              Rails.logger.info("[PubmedIngestService - retrieve_oa_subset] Retrieved #{records.size} records from current page")

              resumption_obj = xml_doc.at_xpath('//resumption/link')
              break unless resumption_obj && resumption_obj['href']

              current_url = resumption_obj['href']
              sleep(0.34) # Respect NCBI rate limits
            end
          end

          Rails.logger.info("[PubmedIngestService - retrieve_oa_subset] Completed OA metadata retrieval into #{output_file}")
        end


        def append_results_to_stored_json_array(file_path, new_results)
          existing_results = read_json(file_path) || []
          combined_results = existing_results + new_results
          File.write(file_path, JSON.pretty_generate(combined_results))
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

        def write_to_json(file_path, obj)
          Rails.logger.info("Writing to JSON file: #{file_path}")
          begin
            File.write(file_path, JSON.pretty_generate(obj))
            message = "Successfully wrote to JSON file: #{file_path}"
            puts message
          rescue StandardError => e
            message = "Error writing to JSON file #{file_path}: #{e.message}"
            puts message
            raise e
          end
        end

        def fallback_id_hash(identifier)
          identifier.start_with?('PMC') ? { pmcid: identifier } : { pmid: identifier }
        end

        def new_article(metadata)
          Rails.logger.info('[Article] Initializing new article object')
          article = Article.new
          article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
          builder = attribute_builder(metadata, article)
          builder.populate_article_metadata
        end

        def alternate_ids_from_xml(xml_doc, article)
          builder = attribute_builder(xml_doc, article)
          pubmed_doc = is_pubmed?(xml_doc)
          alternate_id_array = pubmed_doc ? @record_ids_with_alternate_ids['pubmed'] : @record_ids_with_alternate_ids['pmc']
          builder.find_skipped_row(alternate_id_array)
        end

        def handle_pmc_errors(xml_doc, ids)
          Rails.logger.warn("PMC error found in response for IDs: #{ids.join(', ')}")
          puts "PMC error found in response for IDs: #{ids.join(', ')}"

          error_ids = get_error_ids(xml_doc)

          error_ids.each do |error_id|
            alternate_id_hash = @record_ids_with_alternate_ids['pmc'].find { |h| h['pmcid'] == error_id }

            if alternate_id_hash
              Rails.logger.info("Moving PMC ID #{error_id} to PubMed list")
              @record_ids_with_alternate_ids['pubmed'] << alternate_id_hash
              @record_ids_with_alternate_ids['pmc'].delete(alternate_id_hash)
            else
              Rails.logger.warn("No alternate ID found for PMC ID #{error_id}")
            end
          end
        end

        def get_error_ids(xml_doc)
          xml_doc.xpath('//pmc-articleset/error').map do |error_node|
            error_node['id']
          end
        end

        def process_xml_batches(file_path, batch_size = 500)
          return unless File.exist?(file_path)

          file_content = File.read(file_path)
          xml_strings = JSON.parse(file_content)

          xml_strings.each_slice(batch_size) do |batch|
            nokogiri_batch = batch.map { |xml_str| Nokogiri::XML(xml_str) }

            process_batch(nokogiri_batch)
          end
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

        def add_to_pubmed_id_list(parsed_response)
          ids = parsed_response.xpath('//IdList/Id').map(&:text)
          @record_ids['pubmed'].concat(ids)
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

              # The OA FCGI endpoint does not accept a list of PMCIDs as an argument, so use the retrieved metadata to determine a date range
        # def expand_date_range_for_full_text_retrieval
        #   Rails.logger.info("[PubmedIngestService - expand_date_range_for_full_text_retrieval] Setting date range for full-text retrieval: #{@start_date.strftime('%Y-%m-%d')} to #{@end_date.strftime('%Y-%m-%d')}")
        #   @retrieved_metadata.each do |metadata|
        #     next if is_pubmed?(metadata)

        #     attribute_builder = PmcAttributeBuilder.new(metadata, nil, @admin_set, @depositor.uid)
        #     date_issued = attribute_builder.get_date_issued
        #     update_oa_fgci_date_range(date_issued)
        #   end

        #   # Provide a buffer of 2 years to account for lag between publication and full-text availability
        #   @oa_fgci_end_date += 2.years
        # end

        # def update_oa_fgci_date_range(date_issued)
        #   return unless date_issued.present?
        #   default_date = DateTime.new(0000, 1, 1) # Default date, set in get_date_issued within attribute builders

        #   if date_issued < @oa_fgci_start_date && date_issued > default_date
        #     @oa_fgci_start_date = date_issued
        #     Rails.logger.info("[PubmedIngestService - update_oa_fgci_date_range] Updated OA FGCI start date to: #{@oa_fgci_start_date}")
        #   end
        #   if date_issued > @oa_fgci_end_date
        #     @oa_fgci_end_date = date_issued
        #     Rails.logger.info("[PubmedIngestService - update_oa_fgci_date_range] Updated OA FGCI end date to: #{@oa_fgci_end_date}")
        #   end
        # end
      # def attach_pdf_for_existing_work(work_hash, file_path, depositor_onyen)
        #   begin
        #     # Create a work object using the provided work_hash
        #     model_class = work_hash[:work_type].constantize
        #     work = model_class.find(work_hash[:work_id])
        #     depositor =  User.find_by(uid: depositor_onyen)
        #     file = attach_pdf_to_work(work, file_path, depositor, Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
        #     admin_set = ::AdminSet.where(id: work_hash[:admin_set_id]).first
        #     file.update(permissions_attributes: group_permissions(admin_set))
        #     Rails.logger.info("[AttachPDFExisting] Successfully attached file for #{work_hash[:work_id]}")
        #     file
        # rescue StandardError => e
        #   Rails.logger.error("[AttachPDFExisting] Error finding article for work ID #{work_hash[:work_id]}: #{e.message}")
        #   raise e
        #   end
        # end

              # Update the metadata storage with new metadata to avoid taking up too much memory
        # def update_metadata_storage(file_path:, new_metadata:)
        #   Rails.logger.info("[PubmedIngestService - update_metadata_storage] Writing metadata to file: #{file_path}")

        #   File.open(file_path, 'a') do |f|
        #     new_metadata.each do |xml_node|
        #       f.puts({ xml: xml_node.to_s }.to_json)
        #     end
        #   end
        # end
        # def update_metadata_storage(file_path:, new_metadata:)
        #   # @retrieved_metadata += new_metadata
        #   # if @retrieved_metadata.size > 100
        #   Rails.logger.info("[PubmedIngestService - update_metadata_storage] Writing metadata to file: #{file_path}")
        #   # append_results_to_stored_json_array(file_path, new_metadata)
        #   xml_strings = new_metadata.map(&:to_s)
        #   append_results_to_ndjson(file_path, xml_strings)
        #     # @retrieved_metadata = [] # Reset after writing
        #   # end
        # end

        # def append_results_to_ndjson(file_path, xml_strings)
        #   File.open(file_path, 'a') do |f|
        #     xml_strings.each do |xml_str|
        #       f.puts({ xml: xml_str }.to_json)
        #     end
        #   end
        # end


        # def process_xml_array_test_file(file_path)
        #   complete_xml_array = []
        #   message = "Processing test file: #{file_path}"
        #   puts message
        #   begin
        #     file_content = File.read(file_path)
        #     xml_array = JSON.parse(file_content)
        #     xml_documents = xml_array.map { |xml_str| Nokogiri::XML(xml_str) }
        #     complete_xml_array += xml_documents
        #     message = "Successfully read test file: #{file_path}"
        #     puts message
        #   rescue StandardError => e
        #     message = "Error parsing JSON from file #{file_path}: #{e.message}"
        #     puts message
        #     raise e
        #   end
        #   complete_xml_array
        # end

        # # Read test json file and process into hash
        # def process_test_file(file_path)
        #   message = "Processing test file: #{file_path}"
        #   puts message
        #   begin
        #     file_content = File.read(file_path)
        #     test_data = JSON.parse(file_content)
        #     message = "Successfully read test file: #{file_path}"
        #     puts message
        #   rescue StandardError => e
        #     message = "Error parsing JSON from file #{file_path}: #{e.message}"
        #     puts message
        #     raise e
        #   end
        #   test_data
        # end
      end
    end
  end
end
