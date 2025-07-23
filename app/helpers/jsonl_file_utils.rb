# frozen_string_literal: true
module JsonlFileUtils
  def self.write_jsonl(data, file_path, mode: 'a')
    File.open(file_path, mode, encoding: 'utf-8') do |file|
      data.each do |record|
        file.puts(record.to_json)
      end
    end
    Rails.logger.info("[JsonlFileUtils] Wrote #{data.size} records to #{file_path}")
  rescue StandardError => e
    Rails.logger.error("[JsonlFileUtils] Failed to write to #{file_path}: #{e.message}")
  end

  def self.read_jsonl(file_path)
    return [] unless File.exist?(file_path)

    records = []
    File.foreach(file_path, encoding: 'utf-8') do |line|
      records << JSON.parse(line)
    end
    Rails.logger.info("[JsonlFileUtils] Read #{records.size} records from #{file_path}")
    records
  rescue StandardError => e
    Rails.logger.warn("[JsonlFileUtils] Failed to read from #{file_path}: #{e.message}")
    []
  end
end
