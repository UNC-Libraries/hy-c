# This class is needed to remediate a bug with thumbnails for PDF files whose first page is black and white
# See https://github.com/samvera/hyrax/issues/4971
# TODO:  Once this job has been run successfully on production, we can remove it.

class RegenerateAllDocxThumbnailsJob < Hyrax::ApplicationJob
  # Queueing as import so that it doesn't block works imported via the UI
  queue_as :long_running_jobs

  def perform
    # search_in_batches returns RSolr::Response::PaginatedDocSet, each object in group is a hash of a solr response
    FileSet.office_document_mime_types.each do |mime_type|
      RegenerateAllDocxThumbnailsJob.kick_off_in_batches(mime_type)
    end
  end

  def self.kick_off_in_batches(mime_type)
    FileSet.search_in_batches('mime_type_ssi' => mime_type) do |group|
      Rails.logger.debug("Creating CreateDocxThumbnailJob for filesets with ids: #{group.map { |solr_doc| solr_doc['id'] }}")
      group.map do |solr_doc|
        CreateDocxThumbnailJob.perform_later(file_set_id: solr_doc['id'])
      end
    end
  end
end
