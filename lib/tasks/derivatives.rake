namespace 'derivs' do
  desc "Regenerates thumbnails for PDFs"
  task :thumbs => :environment do
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

  desc "Regenerates derivatives"
  task :all => :environment do
    file_sets = FileSet.all
    file_sets.each do |fs|

      fs.files.each do |file|

        CreateDerivativesJob.perform_later(fs, file.id)
      end
    end
  end
end
