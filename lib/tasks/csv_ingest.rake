namespace :csv do
  desc 'batch ingest from structured csv'
  task :ingest, [:configuration_file] => :environment do |_t, args|
    puts "[#{Time.now}] starting ingest"
    Tasks::CsvIngestService.new(args).ingest
    puts "[#{Time.now}] completed ingest"
  end
end
