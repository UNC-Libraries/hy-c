# frozen_string_literal: true
# [hyc-override] Overriding to allow updated content jobs to run immediately so file reference isn't lost
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/actors/hyrax/actors/file_set_actor.rb
Hyrax::Actors::FileSetActor.class_eval do
  # Spawns synchronous IngestJob with user notification afterward
  # @param [Hyrax::UploadedFile, File, ActionDigest::HTTP::UploadedFile] file the file uploaded by the user
  # @param [Symbol, #to_s] relation
  # @return [IngestJob] the queued job
  def update_content(file, relation = :original_file)
    IngestJob.perform_now(wrapper!(file: file, relation: relation), notification: true)
  end

  def attach_to_work(work, file_set_params = {})
  raise "Intentional error before starting the attach_to_work method"

  acquire_lock_for(work.id) do
    # Ensure we have an up-to-date copy of the members association, so that we append to the end of the list.
    work.reload unless work.new_record?
    file_set.visibility = work.visibility unless assign_visibility?(file_set_params)
    work.ordered_members << file_set
    work.representative = file_set if work.representative_id.blank?
    work.thumbnail = file_set if work.thumbnail_id.blank?
    # Save the work so the association between the work and the file_set is persisted (head_id)
    # NOTE: the work may not be valid, in which case this save doesn't do anything.
    work.save
    Hyrax.config.callback.run(:after_create_fileset, file_set, user, warn: false)
  end
  end

end
