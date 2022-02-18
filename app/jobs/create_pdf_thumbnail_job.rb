# This class is needed to remediate a bug with thumbnails for PDF files whose first page is black and white
# See https://github.com/samvera/hyrax/issues/4971
# TODO:  Once this job has been run successfully on production, we can remove it.

class CreatePdfThumbnailJob < Hyrax::ApplicationJob
  # Queueing as import so that it doesn't block works imported via the UI
  queue_as :import

  def perform(file_set_id:, file_id:)
    Rails.logger.debug("Starting CreatePdfThumbnailJob on file_set: #{file_set_id}, file_id: #{file_id}")
    file_set = FileSet.find(file_set_id)

    if file_id.include?('fcr:versions')
      Rails.logger.debug("Stripping version information from file_id: #{file_id}")
      file_id.slice!(%r{/fcr:versions/version\d})
      file_id
    end
    Rails.logger.debug("file_id after slice is now: #{file_id}")
    target_file = file_set.files.select { |file| file.id == file_id }&.first
    # Do not continue if the file_set and file_id somehow don't match
    return unless target_file
    # Do not continue if the file is not a PDF
    return unless target_file.mime_type == 'application/pdf'

    filename = Hyrax::WorkingDirectory.find_or_retrieve(file_id, file_set_id)
    deriv_service = Hyrax::FileSetDerivativesService.new(file_set)

    Hydra::Derivatives::PdfDerivatives.create(filename,
                                              outputs: [{
                                                label: :thumbnail,
                                                format: 'jpg',
                                                size: '338x493',
                                                url: deriv_service.derivative_url('thumbnail'),
                                                layer: 0
                                              }])
    Rails.logger.debug("Finishing CreatePdfThumbnailJob on file_set: #{file_set_id}, file_id: #{file_id}. Should have saved to: #{deriv_service.derivative_url('thumbnail')}")
  end
end
