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
    today = Date.today
    # Delete articles created today
    Article.all.each do |article|
      if article.create_date.to_date == today
        Rails.logger.info "WIP Destroying article: #{article.id}"
        article.destroy
      end
    end
    # Article.all.each do |article|
    #     article.destroy
    # end
    # ActiveFedora::Base.reindex_everything
    # end WIP


    Rails.logger.info "[#{Time.now}] starting dimensions metadata ingest"

    last_run_time = read_last_run_time('dimensions_ingest')
    if last_run_time
      Rails.logger.info "Last ingest run was at: #{last_run_time}"
    else
      Rails.logger.info 'No previous run time found.'
    end

    # WIP: Replace with 'Open_Acess_Articles_and_Book_Chapters' later
    config = {
      'admin_set' => 'default',
      'depositor_onyen' => 'admin'
    }
    query_service = Tasks::DimensionsQueryService.new
    ingest_service = Tasks::DimensionsIngestService.new(config)
    # WIP: Testing with a smaller page size
    publications = ingest_service.ingest_publications(query_service.query_dimensions)
    report = Tasks::DimensionsReportingService.new(publications).generate_report
    begin
      DimensionsReportMailer.dimensions_report_email(report).deliver_now
      Rails.logger.info 'Dimensions ingest report email sent successfully.'
      # WIP: Logging Ids of Ingested Publications
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
