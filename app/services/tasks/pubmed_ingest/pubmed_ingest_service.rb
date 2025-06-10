# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  module PubmedIngest

    class PubmedIngestService
      attr_reader :attachment_results
      include Tasks::IngestHelper

      def initialize(config)
        raise ArgumentError, 'Missing required config keys' unless config['admin_set_title'] && config['depositor_onyen'] && config['attachment_results'] && config['file_retrieval_directory']

        @file_retrieval_directory = config['file_retrieval_directory']
        @attachment_results = config['attachment_results'].symbolize_keys
        @new_pubmed_works = @attachment_results[:skipped].select { |row| row['pdf_attached'] == 'Skipped: No CDR URL' }
        @attachment_results[:skipped] -= @new_pubmed_works

        @admin_set = ::AdminSet.where(title: config['admin_set_title'])&.first
        raise ActiveRecord::RecordNotFound, "AdminSet not found with title: #{config['admin_set_title']}" unless @admin_set

        @depositor = User.find_by(uid: config['depositor_onyen'])
        raise ActiveRecord::RecordNotFound, "User not found with onyen: #{config['depositor_onyen']}" unless @depositor

        @retrieved_metadata = []
      end

      # Keywords for readability
      def record_result(category:, file_name:, message:, ids: {}, article: nil)
        row = {
          file_name: file_name,
          pdf_attached: message,
          pmid: ids[:pmid],
          pmcid: ids[:pmcid],
          doi: ids[:doi]
        }

        row[:cdr_url] = generate_cdr_url(row) if article
        row[:article] = article if article
        @attachment_results[:counts][category] += 1

        @attachment_results[category] << row
      end


      def ingest_publications
        batch_retrieve_metadata
        Rails.logger.info("[Ingest] Starting ingestion of #{@retrieved_metadata.size} records")

        @retrieved_metadata.each_with_index do |metadata, index|
          Rails.logger.info("[Ingest] Processing record ##{index + 1}")
          begin
            article = new_article(metadata)
            builder = attribute_builder(metadata, article)
            skipped_row = builder.find_skipped_row(@new_pubmed_works)

            Rails.logger.info("[Ingest] Found skipped row: #{skipped_row.inspect}")
            article.save!
            article.identifier.each { |id| Rails.logger.info("[Ingest] Article identifier: #{id}") }
            Rails.logger.info("[Ingest] Created new article with ID #{article.id}")

            attach_pdf(article, skipped_row)
            article.save!

            Rails.logger.info("[Ingest] Successfully attached PDF for article #{article.id}")
            skipped_row['pdf_attached'] = 'Success'
            skipped_row['cdr_url'] = generate_cdr_url(skipped_row)
            skipped_row['article'] = article
            @attachment_results[:successfully_ingested] << skipped_row.to_h
          rescue => e
            doi = skipped_row&.[]('doi') || 'N/A'
            pmid = skipped_row&.[]('pmid') || 'N/A'
            pmcid = skipped_row&.[]('pmcid') || 'N/A'
            Rails.logger.error("[Ingest] Error processing record: DOI: #{doi}, PMID: #{pmid}, PMCID: #{pmcid}, Index: #{index}, Error: #{e.message}")
            Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
            article.destroy if article&.persisted?
            skipped_row['pdf_attached'] = e.message
            @attachment_results[:failed] << skipped_row.to_h
          end
        end

        Rails.logger.info('[Ingest] Ingest complete')
        @attachment_results
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

      def batch_retrieve_metadata
        Rails.logger.info("Starting metadata retrieval for #{@new_pubmed_works.size} records")

        works_with_pmids = @new_pubmed_works.select { |w| w['pmid'].present? }
        works_with_pmcids = @new_pubmed_works.select { |w| !w['pmid'].present?  && w['pmcid'].present? }

        [works_with_pmids, works_with_pmcids].each do |works|
          db = (works.equal?(works_with_pmids)) ? 'pubmed' : 'pmc'
          works.each_slice(200) do |batch|
            ids = batch.map { |w| w['pmid'] || w['pmcid'].sub(/^PMC/, '') }
            request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{db}&id=#{ids.join(',')}&retmode=xml&tool=CDR&email=cdr@unc.edu"
            res = HTTParty.get(request_url)

            if res.code != 200
              Rails.logger.error("Failed to fetch metadata for #{ids.join(', ')}: #{res.code} - #{res.message}")
              next
            end

            xml_doc = Nokogiri::XML(res.body)
            current_arr = xml_doc.xpath(db == 'pubmed' ? '//PubmedArticle' : '//article')
            @retrieved_metadata += current_arr
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

      def generate_cdr_url(skipped_row)
        identifier = skipped_row['pmcid'] || skipped_row['pmid']
        return nil unless identifier.present?

        result = Hyrax::SolrService.get("identifier_tesim:\"#{identifier}\"",
                              rows: 1,
                              fl: 'id,title_tesim,has_model_ssim,file_set_ids_ssim')['response']['docs']
        return nil if result.empty?

        record = result.first
        model = record['has_model_ssim']&.first&.underscore&.pluralize || 'works'
        URI.join(ENV['HYRAX_HOST'], "/concern/#{model}/#{record['id']}").to_s
      rescue => e
        Rails.logger.warn("[generate_cdr_url] Failed for identifier: #{identifier}, error: #{e.message}")
        nil
      end

    end
  end
end
