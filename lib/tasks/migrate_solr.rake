# LOCAL_ENV_FILE=local_env.yml bundle exec rake migrate_solr:list_ids -- -o /tmp/
# LOCAL_ENV_FILE=local_env_solr8.yml bundle exec rake migrate_solr:reindex -- -i /tmp/id_list_2022-06-20T15_40_05Z.txt
require 'time'
require 'optparse'
require 'optparse/date'

namespace :migrate_solr do
  desc 'list object ids for solr migration'
  task :list_ids, [] => :environment do |_t, args|
    start_time = Time.now
    puts "[#{start_time.utc.iso8601}] starting listing of ids"
    options = {}

    opts = OptionParser.new
    opts.banner = "Usage: bundle exec rake migrate_solr:list_ids -- [options]"
    opts.on("-o", "--output-dir ARG", String, 'Directory list will be saved to') { |val| options[:output_dir] = val }
    opts.on("-a", "--after ARG", DateTime, 'List objects which have been updated after this timestamp') { |val| options[:after] = val }
    args = opts.order!(ARGV) {}
    opts.parse!(args)
    
    file_path = Tasks::SolrMigrationService.new().list_object_ids(options[:output_dir], options[:after])

    puts "Listing completed in #{Time.now - start_time}s"
    puts "Stored id list to file: #{file_path}"
  end

  desc 'reindex objects from a list of ids into a new solr version'
  task :reindex, [] => :environment do |_t, args|
    start_time = Time.now
    puts "[#{start_time.utc.iso8601}] starting reindexing to #{ENV['SOLR_PRODUCTION_URL']}"
    options = {}
    opts = OptionParser.new
    opts.banner = "Usage: bundle exec rake migrate_solr:reindex -- [options]"
    opts.on("-i", "--id-list-file ARG", String, 'File path of id list to reindex from') { |val| options[:id_list_file] = val }
    opts.on("-c", "--clean-index", FalseClass, 'Delete all content from the index before populating') { |val| options[:clean_index] = val }
    args = opts.order!(ARGV) {}
    opts.parse!(args)

    puts "[#{Time.now.utc.iso8601}] starting indexing of objects from list file #{options[:id_list_file]}"
    puts "**** Using solr: #{ENV['SOLR_PRODUCTION_URL']}"

    file_path = Tasks::SolrMigrationService.new().reindex(options[:id_list_file], options[:clean_index])
    
    puts "Indexing complete #{Time.now - start_time}s"
  end
end
