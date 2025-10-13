# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService
  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @output_dir = config['output_dir']
    @record_ids = nil
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_ids = Set.new
  end

  def load_last_results
    return Set.new unless File.exist?(@md_ingest_results_path)

    Set.new(
    File.readlines(@md_ingest_results_path).map do |line|
      result = JSON.parse(line.strip)
      [result.dig('ids', 'doi')]
    end.flatten.compact
    )
  end

  private

  def record_result(category:, message: '', ids: {}, article: nil)
    key = ids.compact.values.join('-') # unique key based on pmid/pmcid/doi/work_id
    return if @seen_ids.include?(key) # skip duplicate
    @seen_ids << key
      # Merge article id into ids if article is provided
    log_entry = {
        ids: {
            pmid: ids['pmid'],
            pmcid: ids['pmcid'],
            doi: ids['doi'],
            work_id: article&.id
        },
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
    LogUtilsHelper.double_log("Flushed #{entries.size} entries to #{@md_ingest_results_path}", :info, tag: 'MetadataIngestService')
    rescue => e
      LogUtilsHelper.double_log("Failed to flush buffer to file: #{e.message}", :error, tag: 'MetadataIngestService')
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
  end
end
