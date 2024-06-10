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

    # WIP: Cleaning Articles from Last Manual Test
    # Article.all.each do |article|
    #   article.destroy
    # end
    # ActiveFedora::Base.reindex_everything

    puts "[#{Time.now}] starting dimensions metadata ingest"

    last_run_time = read_last_run_time('dimensions_ingest')
    if last_run_time
      puts "Last ingest run was at: #{last_run_time}"
    else
      puts 'No previous run time found.'
    end
  
    # WIP: Replace with 'Open_Acess_Articles_and_Book_Chapters' later
    config = {
      'admin_set' => 'default',
      'depositor_onyen' => 'admin'
    }
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    # WIP: Testing with a smaller page size
    publications = ingest_service.ingest_publications(query_service.query_dimensions(page_size: 5))
    report = Tasks::DimensionsReportingService.new(publications).generate_report
    DimensionsReportMailer.dimensions_report_email(report).deliver_now
    puts "Ingested #{publications[:ingested].count} publications"
    puts "Failed to ingest #{publications[:failed].count} publications"

    puts "[#{Time.now}] completed dimensions metadata ingest"
    save_last_run_time('dimensions_ingest')
  end
end
