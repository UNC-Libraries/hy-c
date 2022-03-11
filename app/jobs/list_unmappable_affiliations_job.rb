class ListUnmappableAffiliationsJob < Hyrax::ApplicationJob
  queue_as :long_running_jobs

  def perform
    HycCrawlerService.create_csv_of_umappable_affiliations
  end
end
