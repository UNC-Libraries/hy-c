namespace :proquest do
  desc 'batch migrate generic files from FOXML file'
  task :ingest, [:configuration_file] => :environment do |t, args|
    puts "[#{Time.now}] starting proquest ingest"
    Tasks::ProquestIngestService.new(args).migrate_proquest_packages
    puts "[#{Time.now}] completed proquest ingest"
  end
end
