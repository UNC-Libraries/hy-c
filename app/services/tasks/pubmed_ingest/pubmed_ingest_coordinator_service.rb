# frozen_string_literal: true
module Tasks
  module PubmedIngest
    class PubmedIngestCoordinatorService
      def initialize(config)
        @config = config
        @file_retrieval_directory = config['file_retrieval_directory']
        @files_in_dir = file_info_in_dir(@config['file_retrieval_directory'])
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
            total_files: @files_in_dir.length
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
        @results
        # attach_remaining_pdfs
        # finalize_report_and_notify
        # write_results_to_file
      end

      private

      def process_file_matches
        encountered_alternate_ids = []

        @files_in_dir.each do |file_name, file_ext|
          begin
               alternate_ids = retrieve_alternate_ids(file_name)
               unless alternate_ids
                 double_log("No alternate IDs found for #{full_file_name(file_name, file_ext)}", :warn)
                   # @results[:failed] << {
                   # file_name: full_file_name(file_name, file_ext),
                   # pdf_attached: 'Failed: No alternate IDs',
                   # cdr_url: nil
                   # }
                 results[:failed] << build_result_row(file_name, file_ext, {}, 'Failed: No alternate IDs')
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
                   # @results[:successfully_attached] << {
                   #     file_name: full_file_name(file_name, file_ext),
                   #     pdf_attached: 'Success',
                   #     cdr_url: generate_cdr_url(match[:work_id])

                   # }
                 @results[:successfully_attached] << build_result_row(file_name, file_ext, alternate_ids, 'Success', cdr_url: generate_cdr_url(match[:work_id]))
               else
                 double_log("No match found — will be ingested: #{full_file_name(file_name, file_ext)}", :warn)
                   # @results[:skipped] << {
                   # file_name: full_file_name(file_name, file_ext),
                   # pdf_attached: 'Skipped: No CDR URL',
                   # pmid: alternate_ids[:pmid],
                   # pmcid: alternate_ids[:pmcid],
                   # doi: alternate_ids[:doi]
                   # }
                 @results[:skipped] << build_result_row(file_name, file_ext, alternate_ids, 'Skipped: No CDR URL')
               end
               rescue StandardError => e
                 double_log("Error processing file #{file_name}: #{e.message}", :error)
                   # @results[:failed] << {
                   #     file_name: full_file_name(file_name, file_ext),
                   #     pdf_attached: "Failed: #{e.message}",
                   #     pmid: alternate_ids&.dig(:pmid),
                   #     pmcid: alternate_ids&.dig(:pmcid),
                   #     doi: alternate_ids&.dig(:doi)
                   # }
                 @results[:failed] << build_result_row(file_name, file_ext, alternate_ids, "Failed: #{e.message}")
                 next
             end
        end

        update_counts
        double_log("Processing complete. Results: #{@results[:counts]}")
      end

      def attach_remaining_pdfs
        # Iterate over queued attachments and call PdfAttachmentService
      end

      def finalize_report_and_notify
        # Generate report, log, send email
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
            file_set_names: get_filenames(work_data['file_set_ids_ssim'])
          } if work_data.present? && admin_set_data.present?
        end

        nil
      end

      def get_filenames(fileset_ids)
        return [] if fileset_ids.blank?

        fileset_ids.map do |id|
          result = ActiveFedora::SolrService.get("id:#{id}", rows: 1)['response']['docs'].first
          result ? result['title_tesim']&.first : nil
        end.compact
      end

      def retrieve_alternate_ids(identifier)
        begin
            # Use IDConv API to resolve identifiers
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

      def file_info_in_dir(directory)
        abs_path = Pathname.new(directory).absolute? ? directory : Rails.root.join(directory)
        Dir.entries(abs_path)
           .select { |f| !File.directory?(File.join(abs_path, f)) }
           .sort
           .map { |f| [File.basename(f, '.*'), File.extname(f).delete('.')] }
           .uniq
      end

      def log_and_label_skip(file_name, file_ext, alternate_ids, reason)
        full_name = full_file_name(file_name, file_ext)
        double_log("⏭️  #{full_name} - #{reason}", :info)
        # @results[:skipped] << {
        #     file_name: full_name,
        #     pdf_attached: reason,
        #     pmid: alternate_ids[:pmid],
        #     pmcid: alternate_ids[:pmcid],
        #     doi: alternate_ids[:doi]
        # }
        @results[:skipped] << build_result_row(file_name, file_ext, alternate_ids, reason)
      end

      def has_matching_ids?(existing, current)
        [:pmid, :pmcid, :doi].any? { |k| existing[k] == current[k] }
      end

      def update_counts
        @results[:counts][:skipped] = @results[:skipped].length
        @results[:counts][:successfully_attached] = @results[:successfully_attached].length
        @results[:counts][:successfully_ingested] = @results[:successfully_ingested].length
        @results[:counts][:failed] = @results[:failed].length
      end

      def fallback_id_hash(identifier)
        identifier.start_with?('PMC') ? { pmcid: identifier } : { pmid: identifier }
      end

      def full_file_name(name, ext)
        "#{name}.#{ext}"
      end

      def build_result_row(file_name, file_ext, alternate_ids, reason, cdr_url: nil)
        {
            file_name: full_file_name(file_name, file_ext),
            pdf_attached: reason,
            pmid: alternate_ids&.dig(:pmid),
            pmcid: alternate_ids&.dig(:pmcid),
            doi: alternate_ids&.dig(:doi),
            cdr_url: cdr_url
        }.compact
      end


    end
  end
end
