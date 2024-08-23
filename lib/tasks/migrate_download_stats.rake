# frozen_string_literal: true
require 'time'
require 'optparse'
require 'optparse/date'

namespace :migrate_download_stats do
  desc 'list object ids for download stats migration'
  task :list_ids, [:output_dir, :after] => :environment do |_t, _args|
    start_time = Time.now
    puts "[#{start_time.utc.iso8601}] starting listing of ids"
    options = {}

    opts = OptionParser.new
    opts.banner = 'Usage: bundle exec rake migrate_download_stats:list_ids -- [options]'
    opts.on('-o', '--output-dir ARG', String, 'Directory list will be saved to') { |val| options[:output_dir] = val }
    opts.on('-a', '--after ARG', String, 'List objects which have been updated after this timestamp') { |val| options[:after] = val }
    args = opts.order!(ARGV) {}
    opts.parse!(args)

    unless options[:output_dir].present? && options[:output_dir].end_with?('.csv')
      puts 'Please provide a valid output directory with a .csv extension. Got ' + options[:output_dir].to_s
      exit 1
    end

    migration_service = Tasks::DownloadStatsMigrationService.new
    old_stats_csv = migration_service.list_record_info(options[:output_dir], options[:after])
    puts "Listing completed in #{Time.now - start_time}s"
    puts "Stored id list to file: #{options[:output_dir]}"
    exit 0
  end

  desc 'migrate download stats to new table'
  task :migrate, [:csv_path] => :environment do |_t, _args|
    start_time = Time.now
    puts "[#{start_time.utc.iso8601}] Starting migration from CSV to new table"
    options = {}

    opts = OptionParser.new
    opts.banner = 'Usage: bundle exec rake migrate_download_stats:migrate -- [options]'
    opts.on('-c', '--csv-path ARG', String, 'Path to the CSV file to migrate') { |val| options[:csv_path] = val }
    args = opts.order!(ARGV) {}
    opts.parse!(args)

    unless options[:csv_path].present? && File.exist?(options[:csv_path])
      puts 'Please provide a valid CSV file path'
      exit 1
    end

    migration_service = Tasks::DownloadStatsMigrationService.new
    migration_service.migrate_to_new_table(options[:csv_path])
    puts "Migration completed in #{Time.now - start_time}s"
    exit 0
  end
end
