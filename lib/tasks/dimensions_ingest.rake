# frozen_string_literal: true
require_relative './helpers/dimensions_ingest_helper'

namespace :dimensions do
  include DimensionsIngestHelper
  DIMENSIONS_URL = 'https://app.dimensions.ai/api/'

  desc 'Ingest metadata from Dimensions'
  task ingest_metadata: :environment do
    Rake::Task['dimensions:ingest_metadata_task'].invoke
  end

  desc 'Ingest metadata from Dimensions (implementation)'
  task ingest_metadata_task: :environment do
    puts "[#{Time.now}] starting dimensions metadata ingest"
    # Check if the Dimensions API is up
    unless ping_dimensions_api("#{DIMENSIONS_URL}/dsl")
      puts 'Dimensions API is down. Aborting ingest.'
      next
    end

    last_run_time = read_last_run_time('dimensions_ingest')
    if last_run_time
      puts "Last ingest run was at: #{last_run_time}"
    else
      puts 'No previous run time found.'
    end

    config = {
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin'
    }
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    publications = ingest_service.ingest_publications(query_service.query_dimensions)
    puts "Ingested #{publications[:ingested].count} publications"
    puts "Failed to ingest #{publications[:failed].count} publications"

    puts "[#{Time.now}] completed dimensions metadata ingest"
    save_last_run_time('dimensions_ingest')
  end
end
