namespace :onescience do
  desc 'batch migrate 1science articles from spreadsheet'
  task :ingest, [:configuration_file, :rows] => :environment do |_t, args|
    STDOUT.sync = true
    Tasks::OnescienceIngestService.new(args).ingest
  end
end
