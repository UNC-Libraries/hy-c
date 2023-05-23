# frozen_string_literal: true
# Abstract job which performs batch ingest from a provider
class IngestFromProviderJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(user)
    @user = user
    start = Time.now
    Rails.logger.info("Starting ingest job for #{provider}")
    ingest_service.process_all_packages
    Rails.logger.debug("Ingest job for #{provider} completed in #{Time.now - start}")
  end

  def ingest_status_service
    @status_service ||= Tasks::IngestStatusService.status_service_for_provider(provider)
  end
end
