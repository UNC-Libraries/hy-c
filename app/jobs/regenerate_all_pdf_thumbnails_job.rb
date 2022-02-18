# This class is needed to remediate a bug with thumbnails for PDF files whose first page is black and white
# See https://github.com/samvera/hyrax/issues/4971
# TODO:  Once this job has been run successfully on production, we can remove it.

class RegenerateAllPdfThumbnailsJob < Hyrax::ApplicationJob
  # Queueing as import so that it doesn't block works imported via the UI
  queue_as :import

  def perform
    # search_in_batches returns RSolr::Response::PaginatedDocSet, each object in group is a hash of a solr response
    FileSet.search_in_batches('has_model_ssim' => ['FileSet']) do |group|
      Rails.logger.debug("Creating CreatePdfThumbnailJob for filesets with ids: #{group.map { |solr_doc| solr_doc['id'] }}")
      group.map do |solr_doc|
        CreatePdfThumbnailJob.perform_later(file_set_id: solr_doc['id'])
      end
    end
  end
end
