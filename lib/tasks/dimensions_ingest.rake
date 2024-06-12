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
    Rails.logger.info "[#{Time.now}] starting dimensions metadata ingest"

    # WIP: Removing all previously ingested articles for testing purposes
    # Article.find_each do |article|
    #   article.destroy
    # end

    # Read the last run time from a file
    last_run_time = Date.parse(read_last_run_time('dimensions_ingest')) rescue nil
    formatted_last_run_time = last_run_time ? last_run_time.strftime('%Y-%m-%d') : nil

    if last_run_time
      Rails.logger.info "Last ingest run was at: #{last_run_time}"
      formatted_last_run_time = last_run_time.strftime('%Y-%m-%d')
    else
      Rails.logger.info 'No previous run time found. Starting from default date. (1970-01-01)'
    end
    # WIP: Replace with 'Open_Acess_Articles_and_Book_Chapters' later
    config = {
      'admin_set' => 'default',
      'depositor_onyen' => 'admin'
    }
    # Query and ingest publications
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    # WIP: Testing with a limited page size, and no date_inserted. Reinsert date_inserted later
    publications = ingest_service.ingest_publications(query_service.query_dimensions(page_size: 20))
    report = Tasks::DimensionsReportingService.new(publications).generate_report
    begin
      DimensionsReportMailer.dimensions_report_email(report).deliver_now
      Rails.logger.info 'Dimensions ingest report email sent successfully.'
      Rails.logger.info "Ingested Publications: #{publications[:ingested].map { |pub| pub['id'] }}"
      Rails.logger.info "Ingested #{publications[:ingested].count} publications"
      Rails.logger.info "Failed to ingest #{publications[:failed].count} publications"
      Rails.logger.info "[#{Time.now}] completed dimensions metadata ingest"
    rescue StandardError => e
      Rails.logger.error "Failed to send test email: #{e.message}"
    end

    save_last_run_time('dimensions_ingest')
  end
end
