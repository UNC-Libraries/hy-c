# This class is needed to remediate a bug with thumbnails for docx files whose first page is black and white
# This bug was mostly seen on PDFs, but can also be found with docx documents
# See https://github.com/samvera/hyrax/issues/4971
# TODO:  Once this job has been run successfully on production, we can remove it.

class CreateDocxThumbnailJob < Hyrax::ApplicationJob
  # Queueing as a new queue so that it doesn't block works imported via the UI, or the PO's ingest work
  queue_as :long_running_jobs

  def perform(file_set_id:)
    Rails.logger.debug("Starting CreateDocxThumbnailJob on file_set: #{file_set_id}")
    file_set = FileSet.find(file_set_id)
    deriv_service = Hyrax::FileSetDerivativesService.new(file_set)
    target_mime_types = FileSet.office_document_mime_types

    file_set.files.each do |file|
      next unless target_mime_types.include?(file.mime_type)

      filename = Hyrax::WorkingDirectory.find_or_retrieve(file.id, file_set.id)

      Hydra::Derivatives::DocumentDerivatives.create(filename,
                                                     outputs: [{
                                                       label: :thumbnail,
                                                       format: 'jpg',
                                                       size: '338x493',
                                                       url: deriv_service.derivative_url('thumbnail'),
                                                       layer: 0
                                                     }])
      Rails.logger.debug("Finishing CreateDocxThumbnailJob on file_set: #{file_set_id}, file_id: #{file.id}. Should have saved to: #{deriv_service.derivative_url('thumbnail')}")
    end
  end
end
