# frozen_string_literal: true
# bundle exec rake sage:ingest[path_to_my_config]
namespace :sage do
  desc 'batch migrate generic files from Sage deposit'
  task :ingest, [:configuration_file] => :environment do |_t, args|
    puts "[#{Time.now}] starting sage ingest"
    config = YAML.load_file(args[:configuration_file])
    status_service = Tasks::IngestStatusService.status_service_for_source('sage')
    Tasks::SageIngestService.new(config, status_service).process_all_packages
    puts "[#{Time.now}] completed sage ingest"
  end
end
