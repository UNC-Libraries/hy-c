# frozen_string_literal: true
require 'json'
require 'fileutils'

module JsonFileUtilsHelper
  # Write a Ruby object to a JSON file.
  def self.write_json(data, path, pretty: true)
    ensure_dir(path)
    json = pretty ? JSON.pretty_generate(data) : JSON.generate(data)
    File.write(path, json, mode: 'w', encoding: 'utf-8')
    Rails.logger.debug("[JsonFileUtilsHelper] Wrote JSON to #{path}")
    LogUtilsHelper.double_log("[JsonFileUtilsHelper] Wrote JSON to #{path}", :info, tag: 'wip-hyc-2126')
    true
  rescue => e
    Rails.logger.warn("[JsonFileUtilsHelper] write_json failed for #{path}: #{e.message}")
    LogUtilsHelper.double_log("[JsonFileUtilsHelper] write_json failed for #{path}: #{e.message}", :warn, tag: 'wip-hyc-2126')
    false
  end

  # Read a JSON file into a Ruby object.
  def self.read_json(path, symbolize_names: false)
    return nil unless File.exist?(path)
    content = File.read(path, mode: 'r:bom|utf-8')
    JSON.parse(content, symbolize_names: symbolize_names)
  rescue => e
    Rails.logger.warn("[JsonFileUtilsHelper] read_json failed for #{path}: #{e.message}")
    LogUtilsHelper.double_log("[JsonFileUtilsHelper] read_json failed for #{path}: #{e.message}", :warn, tag: 'wip-hyc-2126')
    nil
  end

  # Write an array (or any Enumerable) of records to a JSONL file.
  # mode: "w" to overwrite, "a" to append (default).
  def self.write_jsonl(records, path, mode: 'a')
    ensure_dir(path)
    count = 0
    File.open(path, mode, encoding: 'utf-8') do |f|
      records.each do |record|
        f.puts(record.to_json)
        count += 1
      end
    end
    Rails.logger.debug("[JsonFileUtilsHelper] Wrote #{count} JSONL records to #{path}")
    LogUtilsHelper.double_log("[JsonFileUtilsHelper] Wrote #{count} JSONL records to #{path}", :info, tag: 'wip-hyc-2126')
    count
  rescue => e
    Rails.logger.warn("[JsonFileUtilsHelper] write_jsonl failed for #{path}: #{e.message}")
    LogUtilsHelper.double_log("[JsonFileUtilsHelper] write_jsonl failed for #{path}: #{e.message}", :warn, tag: 'wip-hyc-2126')
    0
  end

  # Read a JSONL file into an array of Ruby objects.
  def self.read_jsonl(path, symbolize_names: false)
    return [] unless File.exist?(path)
    out = []
    File.foreach(path, encoding: 'utf-8') do |line|
      line = line.strip
      next if line.empty?
      out << JSON.parse(line, symbolize_names: symbolize_names)
    end
    out
  rescue => e
    Rails.logger.warn("[JsonFileUtilsHelper] read_jsonl failed for #{path}: #{e.message}")
    LogUtilsHelper.double_log("[JsonFileUtilsHelper] read_jsonl failed for #{path}: #{e.message}", :warn, tag: 'wip-hyc-2126')
    []
  end

  def self.ensure_dir(path)
    dir = File.dirname(path.to_s)
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
  end
end
