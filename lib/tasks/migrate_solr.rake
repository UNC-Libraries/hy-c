# bundle exec rake sage:ingest[path_to_my_config]
namespace :migrate_solr do
  desc 'batch migrate generic files from Sage deposit'
  task :list_ids, [:output_path, :after_timestamp] => :environment do |_t, args|
    puts "[#{Time.now}] starting listing of ids"
    file_path = Tasks::SolrMigrationService.new().list_ids(output_path, after_timestamp)
    puts "[#{Time.now}] stored object list to file #{file_path}"
  end

  task :reindex, [:id_list_file] => :environment do |_t, args|
    puts "[#{Time.now}] starting indexing of objects from list file #{id_list_file}"
    file_path = Tasks::SolrMigrationService.new().reindex(id_list_file)
    puts "[#{Time.now}] finished indexing objects"
  end
end
