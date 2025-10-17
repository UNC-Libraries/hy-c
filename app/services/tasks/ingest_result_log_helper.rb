# frozen_string_literal: true
module Tasks::IngestResultLogHelper
  def record_result(category:, message: '', ids: {}, article: nil)
    doi = ids['doi']
    return if @seen_doi_list.include?(doi) && doi.present?
    @seen_doi_list << doi if doi.present?

    log_entry = {
        ids: ids.merge('work_id' => article&.id),
        timestamp: Time.now.utc.iso8601,
        category: category
    }
    log_entry[:message] = message if message.present?
    @write_buffer << log_entry
    flush_buffer_if_needed
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
end
