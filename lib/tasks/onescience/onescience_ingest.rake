namespace :onescience do
  desc 'batch migrate 1science articles from spreadsheet'
  task :ingest, [:configuration_file] => :environment do |t, args|
    STDOUT.sync = true
    Tasks::OnescienceIngestService.new(args).ingest
  end
end
