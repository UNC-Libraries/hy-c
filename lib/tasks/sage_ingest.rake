# bundle exec rake sage:ingest[path_to_my_config]
namespace :sage do
  desc 'batch migrate generic files from Sage deposit'
  task :ingest, [:configuration_file] => :environment do |_t, args|
    puts "[#{Time.now}] starting sage ingest"
    Tasks::SageIngestService.new(args).process_all_packages
    puts "[#{Time.now}] completed sage ingest"
  end
end
