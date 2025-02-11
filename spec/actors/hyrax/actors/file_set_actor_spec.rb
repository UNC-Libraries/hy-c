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

  describe '#unlink_from_work' do
    let(:work) { FactoryBot.create(:work) }

    context 'work with one file' do
      before do
        actor.attach_to_work(work)
        work.rendering_ids = [file_set.id]
        work.save!
      end

      it 'removes file_set from work' do
        expect(work.thumbnail_id).to eq(file_set.id)
        expect(work.representative_id).to eq(file_set.id)
        expect(work.rendering_ids).to eq([file_set.id])

        actor.unlink_from_work
        work.reload
        expect(work.thumbnail_id).to be_nil
        expect(work.representative_id).to be_nil
        expect(work.rendering_ids).to be_empty
      end
    end

    context 'work with two files' do
      let(:file_set2) { FactoryBot.create(:file_set) }
      let(:actor2) { described_class.new(file_set2, user) }

      before do
        actor.attach_to_work(work)
        actor2.attach_to_work(work)
        work.rendering_ids = [file_set.id, file_set2.id]
        work.save!
      end

      it 'removes file_set from work' do
        expect(work.thumbnail_id).to eq(file_set.id)
        expect(work.representative_id).to eq(file_set.id)
        expect(work.rendering_ids).to eq([file_set.id, file_set2.id])

        actor.unlink_from_work
        work.reload
        expect(work.thumbnail_id).to eq(file_set2.id)
        expect(work.representative_id).to eq(file_set2.id)
        expect(work.rendering_ids).to eq([file_set2.id])
      end
    end
  end
end
