namespace 'derivs' do
  desc 'Regenerates thumbnails for PDFs'
  task pdf_thumbs: :environment do
    RegenerateAllPdfThumbnailsJob.perform_later
  end

  desc 'Regenerates thumbnails for Docx documents'
  task docx_thumbs: :environment do
    RegenerateAllDocxThumbnailsJob.perform_later
  end

  desc 'Regenerates derivatives for a single file set'
  task :file_set, [:id] => :environment do |_t, args|
    file_set = FileSet.find(args.id)
    puts "Could not find FileSet with id: #{args.id}" unless file_set
    return unless file_set

    file_set.files.each do |file|
      # Do not try to create a derivative of the text file that's generated alongside PDFs
      # Since it is, itself, a derivative
      next if file.mime_type == 'text/plain;charset=UTF-8'

      CreateDerivativesJob.perform_later(file_set, file.id)
    end
  end
end
