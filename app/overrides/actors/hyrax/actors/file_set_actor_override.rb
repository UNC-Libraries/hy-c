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

  # [hyc-override] Fall back to the next fileset for thumbnail/represenatative if there are any remaining in the work
  def unlink_from_work
    work = parent_for(file_set: file_set)
    return unless work && (work.thumbnail_id == file_set.id || work.representative_id == file_set.id || work.rendering_ids.include?(file_set.id))

    remaining_members = work.members.to_a.reject { |member| member.id == file_set.id }
    if remaining_members.empty?
      work.thumbnail = nil
      work.representative = nil
    else
      work.thumbnail = remaining_members.first
      work.representative = remaining_members.first
    end

    work.rendering_ids -= [file_set.id]
    work.save!
  end
end
