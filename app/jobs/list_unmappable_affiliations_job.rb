# frozen_string_literal: true
class ListUnmappableAffiliationsJob < Hyrax::ApplicationJob
  queue_as :long_running_jobs

  def perform
    HycCrawlerService.create_csv_of_unmappable_affiliations
  end
end
