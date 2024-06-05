# lib/tasks/dimensions_ingest.rake
require_relative 'helpers/dimensions_ingest_helper'

namespace :dimensions do
  include DimensionsIngestHelper

    desc "Ingest metadata from Dimensions"
    task ingest_metadata: :environment do
      Rake::Task["dimensions:ingest_metadata_task"].invoke
    end
  
    desc "Ingest metadata from Dimensions (implementation)"
    task ingest_metadata_task: :environment do
      puts "[#{Time.now}] starting dimensions metadata ingest"
      last_run_time = read_last_run_time('dimensions_ingest')
      if last_run_time
        puts "Last ingest run was at: #{last_run_time}"
      else
        puts "No previous run time found."
      end
  
      puts "[#{Time.now}] completed dimensions metadata ingest"
      save_last_run_time('dimensions_ingest')
    end
  end
  