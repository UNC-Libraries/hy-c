# frozen_string_literal: true
require 'time'
require 'optparse'
require 'optparse/date'

namespace :migrate_download_stats do
  desc 'output rows for download stat migration into a csv'
  task :list_rows, [:output_path, :after, :before, :source, :ga_stats_path] => :environment do |_t, _args|
    start_time = Time.now
    puts "[#{start_time.utc.iso8601}] starting listing of work data"
    options = {}

    opts = OptionParser.new
    opts.banner = 'Usage: bundle exec rake migrate_download_stats:list_rows -- [options]'
    opts.on('-o', '--output-dir ARG', String, 'Directory list will be saved to') { |val| options[:output_path] = val }
    opts.on('-a', '--after ARG', String, 'List objects which have been updated after this timestamp') { |val| options[:after] = val }
    opts.on('-b', '--before ARG', String, 'List objects updated before this timestamp, only meant for matomo and ga4 migrations') { |val| options[:before] = val }
    opts.on('-s', '--source ARG', String, 'Data source (matomo, ga4, cache)') { |val| options[:source] = val.to_sym }
    opts.on('-ga', '--ga4-stats-dir ARG', String, 'Path to directory containing ga4 stats') { |val| options[:ga_stats_path] = val }
    args = opts.order!(ARGV) {}
    opts.parse!(args)

    unless options[:output_path].present? && options[:output_path].end_with?('.csv')
      puts 'Please provide a valid output directory with a .csv extension. Got ' + options[:output_path].to_s
      exit 1
    end

    unless Tasks::DownloadStatsMigrationService::DownloadMigrationSource.valid?(options[:source])
      puts "Please provide a valid source: #{Tasks::DownloadStatsMigrationService::DownloadMigrationSource.all_sources.join(', ')}"
      exit 1
    end

    # Require both 'before' and 'after' arguments if the source is not 'cache' or 'ga4'
    if options[:source] == Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO && (!options[:before].present? || !options[:after].present?)
      puts "Both 'before' and 'after' timestamps are required for #{Tasks::DownloadStatsMigrationService::DownloadMigrationSource::MATOMO}"
      exit 1
    end

    if options[:source] == Tasks::DownloadStatsMigrationService::DownloadMigrationSource::GA4 && !options[:ga_stats_path].present?
      puts 'Please provide a path to the directory containing GA4 stats (use -ga option)'
      exit 1
    end


    migration_service = Tasks::DownloadStatsMigrationService.new
    old_stats_csv = migration_service.list_work_stat_info(options[:output_path], options[:source], options[:after],  options[:before], options[:ga_stats_path])
    puts "Listing completed in #{Time.now - start_time}s"
    puts "Stored id list to file: #{options[:output_path]}"
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
