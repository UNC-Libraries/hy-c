# frozen_string_literal: true
class ReindexJob < Hyrax::ApplicationJob
  queue_as :long_running_jobs

  def perform
    Samvera::NestingIndexer.reindex_all!(extent: Hyrax::Adapters::NestingIndexAdapter::FULL_REINDEX)
  end
end
