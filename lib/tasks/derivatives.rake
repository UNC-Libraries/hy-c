namespace 'derivs' do
  desc 'Regenerates thumbnails for PDFs'
  task pdf_thumbs: :environment do
    file_sets = FileSet.where(mime_type_ssi: 'application/pdf')
    file_sets.each do |fs|
      # Only regenerate the FileSet that creates the thumbnail
      next unless fs.id == fs.parent.thumbnail_id

      fs.files.each do |file|
        next unless file.mime_type == 'application/pdf'

        CreateDerivativesJob.perform_later(fs, file.id)
      end
    end
  end

  desc 'Regenerate derivatives for all FileSets in the repository'
  task all: :environment do
    FileSet.all.each do |file_set|
      file_set.files.each do |file|
        # Do not try to create a derivative of the text file that's generated alongside PDFs
        # Since it is, itself, a derivative
        next if file.mime_type == 'text/plain;charset=UTF-8'

        CreateDerivativesJob.perform_later(file_set, file.id)
      end
    end
  end
end
