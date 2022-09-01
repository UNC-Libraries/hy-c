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

  describe '#update_content' do
    it 'calls perform_now and returns ingest job' do
      expect(IngestJob).to receive(:perform_now).with(any_args).and_return(IngestJob.new)
      expect(actor.update_content(file)).to be_a(IngestJob)
    end
  end
end
