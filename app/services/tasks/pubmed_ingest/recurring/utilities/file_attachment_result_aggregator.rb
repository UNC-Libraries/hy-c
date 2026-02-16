# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentResultAggregator
  def initialize(attachment_results_path:, output_path:)
    @attachment_results_path = attachment_results_path
    @output_path = output_path
  end

  def aggregate_results
    # Default structure for grouped results
    grouped = Hash.new { |h, k| h[k] = Set.new }

    File.readlines(@attachment_results_path).each do |line|
      entry = JSON.parse(line.strip)

      # Create a key based on unique ids + category + message to group similar entries
      key = {
        pmid: entry.dig('ids', 'pmid'),
        pmcid: entry.dig('ids', 'pmcid'),
        doi: entry.dig('ids', 'doi'),
        work_id: entry.dig('ids', 'work_id'),
        category: entry.dig('category'),
        message: entry.dig('message')
      }

      # Store filenames under the grouped key
      grouped[key] << entry['file_name']
    end

    # Convert aggregated results to an array format
    aggregated_results = grouped.map do |key, filename_array|
      {
        ids: {
          pmid: key[:pmid],
          pmcid: key[:pmcid],
          doi: key[:doi],
          work_id: key[:work_id]
        },
        category: key[:category],
        message: key[:message],
        filenames: filename_array
      }
    end

    # Write aggregated results to output JSONL file
    JsonFileUtilsHelper.write_jsonl(aggregated_results, @output_path, mode: 'w')
  end
end
