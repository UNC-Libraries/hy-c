# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/actors/hyrax/actors/file_actor.rb
Hyrax::Actors::FileActor.class_eval do

  def ingest_file(io)
    Hydra::Works::AddFileToFileSet.call(file_set,
                                        io,
                                        relation,
                                        versioning: false)
    # [hyc-override] Raise an error if the file_set cannot save
    file_set.save!

    repository_file = related_file
    create_version(repository_file, user)
    # [hyc-override] Invoke longleaf registration
    RegisterToLongleafJob.perform_later(repository_file.checksum.value)
    CharacterizeJob.perform_later(file_set, repository_file.id, pathhint(io))
  rescue ActiveFedora::RecordInvalid => error
    # [hyc-override] rescue and log the error, finally return false after logging
    Rails.logger.error("Could not save FileSet with id: #{file_set.id} after adding file due to error: #{error}")
    false
  end
end
