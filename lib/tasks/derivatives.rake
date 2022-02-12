namespace 'derivs' do
  desc 'Regenerates thumbnails for PDFs'
  task pdf_thumbs: :environment do
    RegeneratePdfThumbnailsJob.perform_later
  end

  desc 'Regenerate derivatives for all FileSets in the repository'
  task all: :environment do
    FileSet.all.each do |file_set|
      file_set.files.each do |file|
        # Only regenerate the FileSet that creates the thumbnail
        next unless fs.id == fs.parent.thumbnail_id
        # Do not try to create a derivative of the text file that's generated alongside PDFs
        # Since it is, itself, a derivative
        next if file.mime_type == 'text/plain;charset=UTF-8'

        CreateDerivativesJob.perform_later(file_set, file.id)
      end
    end
  end

  desc 'Regenerate derivatives for a single thumbnail'
  task :file_set, [:id] => :environment do |_t, args|
    file_set = FileSet.find(args.id)
    puts "Could not find FileSet with id: #{args.id}" unless file_set
    return unless file_set

    file_set.files.each do |file|
      # Only regenerate the FileSet that creates the thumbnail
      next unless file_set.id == file_set.parent.thumbnail_id
      # Do not try to create a derivative of the text file that's generated alongside PDFs
      # Since it is, itself, a derivative
      next if file.mime_type == 'text/plain;charset=UTF-8'

      CreateDerivativesJob.perform_later(file_set, file.id)
    end
  end
end
