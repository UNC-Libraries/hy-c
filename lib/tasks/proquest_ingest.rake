# frozen_string_literal: true
namespace :proquest do
  desc 'batch migrate generic files from FOXML file'
  task :ingest, [:configuration_file] => :environment do |_t, args|
    puts "[#{Time.now}] starting proquest ingest"
    Tasks::ProquestIngestService.new(args).process_all_packages
    puts "[#{Time.now}] completed proquest ingest"
  end
end
