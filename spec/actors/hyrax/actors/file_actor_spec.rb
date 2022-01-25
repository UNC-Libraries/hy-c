require 'rails_helper'

RSpec.describe Hyrax::Actors::FileActor do
  let(:file_set) { FactoryBot.create(:file_set) }
  let(:user) { FactoryBot.create(:user) }
  let(:actor) { described_class.new(file_set, :original_file, user) }
  let(:file_path) { File.join(fixture_path, 'files', 'image.png') }
  let(:file) { File.new(file_path) }
  let(:job_wrapper) { JobIoWrapper.create_with_varied_file_handling!(file_set: file_set, user: user, file: file, relation: 'some_string') }

  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
  end

  it 'can be instantiated' do
    expect(actor).to be_instance_of(described_class)
  end

  it 'can ingest a file' do
    expect(CharacterizeJob).to receive(:perform_later)
    actor.ingest_file(job_wrapper)
  end

  context 'with a file_set that fails validation' do
    before do
      # one of the FileSet validations is whether the file has a virus - mock that it does
      allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { true }
    end

    it 'logs an error' do
      allow(Rails.logger).to receive(:error)

      actor.ingest_file(job_wrapper)

      expect(Rails.logger).to have_received(:error).with(("Could not save FileSet with id: #{file_set.id} after adding file due to error: Validation failed: Failed to verify uploaded file is not a virus"))
    end
  end
end
