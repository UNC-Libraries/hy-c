# frozen_string_literal: true
module Tasks::IngestHelperUtils::ReportingHelper
  extend self

  def format_results_for_reporting(raw_results_array:, tracker:)
    results = initialize_category_hash(tracker)
    raw_results_array.each do |entry|
      category = entry[:category]&.to_sym
      next unless results.key?(category)
      entry.merge!(entry.delete(:ids) || {})
      entry[:cdr_url] = WorkUtilsHelper.generate_cdr_url_for_work_id(entry[:work_id]) if entry[:work_id].present?
      results[category] << entry
    end
    results
  end

  def initialize_category_hash(tracker)
    {
      skipped: [],
      skipped_file_attachment: [],
      successfully_attached: [],
      successfully_ingested_metadata_only: [],
      successfully_ingested_and_attached: [],
      failed: [],
      skipped_non_unc_affiliation: [],
      time: tracker['restart_time'] || tracker['start_time'],
      headers: { total_unique_records: 0 }
    }
  end

  def generate_result_csvs(results:, csv_output_dir:)
    csv_paths = []
    results.each do |category, records|
      next if records.empty? || !records.is_a?(Array)
      path = File.join(csv_output_dir, "#{category}.csv")
      CSV.open(path, 'wb') do |csv|
        csv << records.first.keys
        records.each { |record| csv << record.values }
      end
      csv_paths << path
    end
    csv_paths
  end

  def compress_result_csvs(csv_paths:, zip_output_dir:)
    zip_path = File.join(csv_output_dir, 'ingest_results.zip')
    Zip::File.open(zip_path, Zip::File::CREATE) do |zip|
      csv_paths.each { |path| zip.add(File.basename(path), path) if File.exist?(path) }
    end
    zip_path
  end

  def generate_truncated_categories(report, max_rows: 100)
    trunc_categories = []

    report.each do |category, records|
      if records.empty? || !records.is_a?(Array)
        LogUtilsHelper.double_log(
            "No records for #{category}, skipping CSV generation",
            :info,
            tag: 'generate_result_csvs'
        )
        next
      end

      trunc_categories << category.to_s if records.size > max_rows
    end

    trunc_categories
  end
end
