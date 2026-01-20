# frozen_string_literal: true
class Tasks::NoaaIngest::Backlog::Utilities::FileAttachmentResultAggregator
  def initialize(attachment_results_path:, output_path:)
    @attachment_results_path = attachment_results_path
    @output_path = output_path
  end

  def aggregate_results
      # Default structure for grouped results
    grouped = Hash.new { |h, k| h[k] = [] }

    File.readlines(@attachment_results_path).each do |line|
      entry = JSON.parse(line.strip)

        # Create a key based on unique ids + category + message to group similar entries
      key = {
          noaa_id: entry.dig('ids', 'noaa_id'),
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
              noaa_id: key[:noaa_id],
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
