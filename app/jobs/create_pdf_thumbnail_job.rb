# This class is needed to remediate a bug with thumbnails for PDF files whose first page is black and white
# See https://github.com/samvera/hyrax/issues/4971
# TODO:  Once this job has been run successfully on production, we can remove it.

class CreatePdfThumbnailJob < Hyrax::ApplicationJob
  # Queueing as import so that it doesn't block works imported via the UI
  queue_as :import

  def perform(file_set_id:, file_id:)
    file_set = FileSet.find(file_set_id)

    # There is no method I can find to directly ask "What is the mime_type of the file with ID foo?", so this is my
    # indirect way of doing so
    mime_type_map = file_set.files.map { |file| { mime_type: file.mime_type, file_id: file.id } }
    target_file = mime_type_map.select { |file| file[:file_id] == file_id }&.first

    # Do not continue if the file_set and file_id somehow don't match
    return unless target_file
    # Do not continue if the file is not a PDF
    return unless target_file[:mime_type] == 'application/pdf'

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
  end
end
