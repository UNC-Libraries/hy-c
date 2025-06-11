# frozen_string_literal: true
module Tasks
  module PubmedIngest
    class PubmedIngestCoordinatorService
      def initialize(config)
        @config = config
        @file_retrieval_directory = config['file_retrieval_directory']
        @files_in_dir = retrieve_filenames(@config['file_retrieval_directory'])
        @output_dir = config['output_dir'] || Rails.root.join('tmp')
        @depositor_onyen = config['depositor_onyen']
        @results = {
          skipped: [],
          successfully_attached: [],
          successfully_ingested: [],
          failed: [],
          time: Time.now,
          depositor: config['depositor_onyen'],
          file_retrieval_directory: config['file_retrieval_directory'],
          output_dir: config['output_dir'],
          admin_set: config['admin_set_title'],
          counts: {
            total_files: @files_in_dir.length,
            skipped: 0,
            successfully_attached: 0,
            successfully_ingested: 0,
            failed: 0
          }
        }
        @pubmed_ingest_service = PubmedIngestService.new({
            'admin_set_title' => config['admin_set_title'],
            'depositor_onyen' => config['depositor_onyen'],
            'attachment_results' => @results,
            'file_retrieval_directory' => config['file_retrieval_directory']
        })
      end

      def run
        process_file_matches
        attach_remaining_pdfs
        write_results_to_file
        finalize_report_and_notify
        @pubmed_ingest_service.attachment_results
      end

      private

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

               if encountered_alternate_ids.any? { |ids| has_matching_ids?(ids, alternate_ids) }
                 log_and_label_skip(file_name, file_ext, alternate_ids, 'Already encountered this work during current run')
                 next
               else
                 encountered_alternate_ids << alternate_ids
               end


               match = find_best_work_match(alternate_ids)

               if match&.dig(:file_set_names).present?
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
                        article: WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id]),
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
          Rails.logger.error(e.backtrace.join("\n"))
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
          report = Tasks::PubmedIngest::PubmedReportingService.generate_report(@pubmed_ingest_service.attachment_results)
          PubmedReportMailer.pubmed_report_email(report).deliver_now
          double_log('Email sent successfully', :info)
        rescue StandardError => e
          double_log("Failed to send email: #{e.message}", :error)
          double_log(e.backtrace.join("\n"))
        end
      end

    # Helper methods

      def find_best_work_match(alternate_ids)
        [alternate_ids[:doi], alternate_ids[:pmcid], alternate_ids[:pmid]].each do |id|
          next if id.blank?

          work_data = ActiveFedora::SolrService.get("identifier_tesim:\"#{id}\"", rows: 1)['response']['docs'].first
          next unless work_data

          admin_set_name = work_data['admin_set_tesim']&.first
          admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:\"#{admin_set_name}\" AND has_model_ssim:(\"AdminSet\")", rows: 1)['response']['docs'].first : {}

          return {
            work_id: work_data['id'],
            work_type: work_data.dig('has_model_ssim', 0),
            title: work_data['title_tesim']&.first,
            admin_set_id: admin_set_data['id'],
            admin_set_name: admin_set_name,
            file_set_names: WorkUtilsHelper.get_filenames(work_data['file_set_ids_ssim'])
          } if work_data.present? && admin_set_data.present?
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

      def generate_cdr_url(work_id)
        "https://cdr.lib.unc.edu/concern/works/#{work_id}"
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
  end
end
