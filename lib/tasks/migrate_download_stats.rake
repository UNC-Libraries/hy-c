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

    unless options[:output_dir].present? && options[:output_dir][-4] == '.csv'
      puts 'Please provide a valid output directory with a .csv extension'
      exit 1
    end

    file_path = Tasks::DownloadStatsMigrationService.new.list_record_info(options[:output_dir], options[:after])

    puts "Listing completed in #{Time.now - start_time}s"
    puts "Stored id list to file: #{file_path}"
    exit 0
  end
end
