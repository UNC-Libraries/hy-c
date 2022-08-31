# frozen_string_literal: true
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/actors/hyrax/actors/file_set_actor_override.rb')

RSpec.describe Hyrax::Actors::FileSetActor do
  let(:file_set) { FactoryBot.create(:file_set) }
  let(:user) { FactoryBot.create(:user) }
  let(:file_path) { File.join(fixture_path, 'files', 'image.png') }
  let(:file) { File.new(file_path) }
  let(:relation) { :original_file }
  let(:actor) { described_class.new(file_set, user) }
  let(:file_actor)  { Hyrax::Actors::FileActor.new(file_set, relation, user) }

  describe '#update_content' do
    it 'calls ingest_file and returns ingest job' do
      expect(IngestJob).to receive(:perform_now).with(any_args).and_return(IngestJob.new)
      expect(actor.update_content(file)).to be_a(IngestJob)
    end

    it 'runs callbacks' do
      # Do not bother ingesting the file -- test only the result of callback
      allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
      allow(file_actor).to receive(:ingest_file).with(any_args).and_return(double)
      expect(ContentNewVersionEventJob).to receive(:perform_later).with(file_set, user)
      actor.update_content(file)
    end
  end
end
