# This class is needed to remediate a bug with thumbnails for PDF files whose first page is black and white
# See https://github.com/samvera/hyrax/issues/4971
# TODO:  Once this job has been run successfully on production, we can remove it.

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
