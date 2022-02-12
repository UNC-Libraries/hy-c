class RegeneratePdfThumbnailsJob < Hyrax::ApplicationJob
  queue_as :derivatives

  def perform
    pdf_file_sets.map do |fs|
      fs.files.each do |file|
        next unless file.mime_type == 'application/pdf'

        CreateDerivativesJob.perform_later(fs, file.id)
      end
    end

    pdf_file_sets.map(&:id)
  end

  def pdf_file_sets
    @pdf_file_sets ||= FileSet.where(mime_type_ssi: 'application/pdf')
  end
end
