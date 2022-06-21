# bundle exec rake migrate_solr:list_ids[/tmp/]
# bundle exec rake migrate_solr:reindex[/tmp/id_list_2022-06-17T21_15_18Z.txt]
require 'time'
namespace :migrate_solr do
  desc 'batch migrate generic files from Sage deposit'
  task :list_ids, [:output_path, :after_timestamp] => :environment do |_t, args|
    puts "[#{Time.now.utc.iso8601}] starting listing of ids"
    file_path = Tasks::SolrMigrationService.new().list_object_ids(args.output_path, args.after_timestamp)
    puts "[#{Time.now.utc.iso8601}] stored object list to file #{file_path}"
  end

  task :reindex, [:id_list_file] => :environment do |_t, args|
    puts "RAILS_ENV: #{ENV['RAILS_ENV']}"
    puts "[#{Time.now.utc.iso8601}] starting indexing of objects from list file #{args.id_list_file}"
    puts "Using solr: #{ENV['SOLR_PRODUCTION_URL']}"
    file_path = Tasks::SolrMigrationService.new().reindex(args.id_list_file)
    puts "[#{Time.now.utc.iso8601}] finished indexing objects"
  end
end
