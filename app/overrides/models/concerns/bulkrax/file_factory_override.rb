# frozen_string_literal: true
# https://github.com/samvera/bulkrax/blob/v9.5.1/app/models/concerns/bulkrax/file_factory.rb

module HycBulkraxFileFactoryOverride
  # [hyc-override] Overriding set_removed_filesets to not hardcode updates as PNG files and set file set
  # to private if the file set is being replaced.
  def remove_file_set(file_set:)
    # TODO: We need to consider the Valkyrie pathway
    file = file_set.files.first
    file.create_version

    opts = {
        path: file.id.split('/', 2).last,
        original_name: file.original_name,
        mime_type: file.mime_type
    }

    file_set.add_file(File.open(Bulkrax.removed_image_path), opts)
    file_set.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE unless @update_files
    file_set.save
    ::CreateDerivativesJob.set(wait: 1.minute).perform_later(file_set, file_set.files.first.id)
  end
end
Bulkrax::FileFactory.prepend(HycBulkraxFileFactoryOverride)
