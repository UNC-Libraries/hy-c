# frozen_string_literal: true
# [hyc-override] Overriding to allow updated content jobs to run immediately so file reference isn't lost
# https://github.com/samvera/hyrax/blob/v2.9.6/app/actors/hyrax/actors/file_set_actor.rb
Hyrax::Actors::FileSetActor.class_eval do
  # Spawns synchronous IngestJob with user notification afterward
  # @param [Hyrax::UploadedFile, File, ActionDigest::HTTP::UploadedFile] file the file uploaded by the user
  # @param [Symbol, #to_s] relation
  # @return [IngestJob] the queued job
  def update_content(file, relation = :original_file)
    IngestJob.perform_now(wrapper!(file: file, relation: relation), notification: true)
  end
end
