# frozen_string_literal: true
module Tasks
  module IngestHelperUtils
    module MetadataIngestHelper
      def record_result(category:, message: '', identifier: nil, article: nil, filename: nil)
        identifier_key = identifier_key_name # Implemented by including class
        @seen_identifier_list << identifier if identifier.present?

        ids = { identifier_key => identifier, 'work_id' => article&.id&.to_s }
        alternate_ids = extract_alternate_ids_from_article(article, category)
        ids.merge!(alternate_ids) if alternate_ids.present?

        log_entry = {
          ids: ids,
          timestamp: Time.now.utc.iso8601,
          category: category,
          filename: filename
        }
        log_entry[:message] = message if message.present?

        @write_buffer << log_entry
        flush_buffer_if_needed
      end

      def extract_alternate_ids_from_article(article, category)
        negative_categories = [:skipped, :skipped_non_unc_affiliation, :failed]
        return nil if article.nil? || negative_categories.include?(category)

        work_hash = WorkUtilsHelper.fetch_work_data_by_id(article.id, admin_set_title: @config['admin_set_title'])
        return nil if work_hash.blank?

        {
          'pmid' => work_hash[:pmid],
          'pmcid' => work_hash[:pmcid]
        }.compact
      end

      def flush_buffer_if_needed
        return if @write_buffer.size < @flush_threshold
        flush_buffer_to_file
      end

      def flush_buffer_to_file
        entries = @write_buffer.dup
        File.open(@md_ingest_results_path, 'a') { |file| entries.each { |entry| file.puts(entry.to_json) } }
        @write_buffer.clear
        LogUtilsHelper.double_log("Flushed #{entries.size} entries to #{@md_ingest_results_path}", :info, tag: self.class.name)
      rescue => e
        LogUtilsHelper.double_log("Failed to flush buffer to file: #{e.message}", :error, tag: self.class.name)
        Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      end

      def load_last_results(identifier_key)
        return Set.new unless File.exist?(@md_ingest_results_path)

        Set.new(File.readlines(@md_ingest_results_path).map do |line|
          result = JSON.parse(line.strip)
          result.dig('ids', identifier_key)
        end.flatten.compact)
      end

      def skip_existing_work(identifier, match, filename: nil)
        identifier_key = identifier_key_name
        Rails.logger.info("[MetadataIngestService] Skipping work with #{identifier_key} #{identifier} — already exists.")
        article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
        record_result(category: :skipped, message: 'Pre-filtered: work exists', identifier: identifier, article: article, filename: nil)
      end

      def handle_record_error(identifier_or_record, error, filename: nil)
        identifier = identifier_or_record.is_a?(Hash) ? identifier_or_record[identifier_key_name] : identifier_or_record
        identifier_key = identifier_key_name

        Rails.logger.error("[MetadataIngestService] Error processing work with #{identifier_key} #{identifier}: #{error.message}")
        Rails.logger.error(error.backtrace.join("\n"))
        record_result(category: :failed, message: error.message, identifier: identifier, article: nil, filename: filename)
      end

      # To be implemented by including class
      def identifier_key_name
        raise NotImplementedError, "#{self.class} must implement #identifier_key_name"
      end
    end
  end
end
