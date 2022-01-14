desc "Regenerates thumbnails for PDFs"
task :regen_thumbs => :environment do
  file_sets = FileSet.where(mime_type_ssi: "application/pdf")
  file_sets.each do |fs|
    # Only regenerate the FileSet that creates the thumbnail
    next unless fs.id == fs.parent.thumbnail_id
    fs.files.each do |file|
      next unless file.mime_type == "application/pdf"
      CreateDerivativesJob.perform_later(fs, file.id)
    end
  end
end
