# frozen_string_literal: true

Bulkrax::FileFactory.module_eval do
  def set_removed_filesets
    local_file_sets.each do |fileset|
      fileset.files.first.create_version
      opts = {}
      opts[:path] = fileset.files.first.id.split('/', 2).last
      opts[:original_name] = fileset.files.first.original_name
      opts[:mime_type] = fileset.files.first.mime_type

      fileset.add_file(File.open(Bulkrax.removed_image_path), opts)
      fileset.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE unless @update_files
      fileset.save
      ::CreateDerivativesJob.set(wait: 1.minute).perform_later(fileset, fileset.files.first.id)
    end
  end
end
