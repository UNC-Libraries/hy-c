class CreateDerivativesJob < Hyrax::ApplicationJob
  queue_as :derivatives

  # @param [FileSet] file_set
  # @param [String] file_id identifier for a Hydra::PCDM::File
  # @param [String, NilClass] filepath the cached file within the Hyrax.config.working_path
  def perform(file_set, file_id, filepath = nil)
    # [hyc-override] cleanup video file even if ffmpeg is disabled
    if file_set.video? && !Hyrax.config.enable_ffmpeg
      cleanup_working_file(filepath)
      return
    end
    return if file_set.video? && !Hyrax.config.enable_ffmpeg
    working_file = Hyrax::WorkingDirectory.find_or_retrieve(file_id, file_set.id, filepath)
    file_set.create_derivatives(working_file)

    # Reload from Fedora and reindex for thumbnail and extracted text
    file_set.reload
    file_set.update_index
    file_set.parent.update_index if parent_needs_reindex?(file_set)

    # [hyc-override] this is the last job, so cleanup the working file
    cleanup_working_file(working_file)
  end

  # [hyc-override] Deletes the working file if it is in the working_files directory
  def cleanup_working_file(file_path)
    # Expand path prior to delete in case it contains modifiers
    working_file = Pathname.new(file_path).expand_path.to_s
    working_path = Hyrax.config.working_path
    # Ensure the referenced file is from the working files directory
    if working_file.start_with?(working_path)
      file_dir = File.dirname(working_file)
      Rails.logger.info("Finished with derivatives, cleaning up working file: #{file_dir}")
      FileUtils.rm_rf(file_dir)
    end
  end

  # If this file_set is the thumbnail for the parent work,
  # then the parent also needs to be reindexed.
  def parent_needs_reindex?(file_set)
    return false unless file_set.parent
    file_set.parent.thumbnail_id == file_set.id
  end
end
