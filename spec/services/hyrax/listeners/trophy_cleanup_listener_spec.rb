# frozen_string_literal: true
require 'rails_helper'

# Load the override being tested
require Rails.root.join('app/overrides/services/hyrax/listeners/trophy_cleanup_listener_override.rb')

RSpec.describe Hyrax::Listeners::TrophyCleanupListener do
  let(:listener) { described_class.new }

  describe '#on_object_deleted' do
    let(:payload) { { id: 'z890s9938' } }
    let(:event) { instance_double(Dry::Events::Event, payload: payload) }
    let(:target_work_id) { payload[:object]&.id || payload[:id] }

    before do
      Trophy.where(work_id: [target_work_id, 'other-work']).delete_all
      Trophy.create!(user_id: 1, work_id: target_work_id)
      Trophy.create!(user_id: 2, work_id: 'other-work')
    end

    it 'deletes trophies when the event only includes an id' do
      expect { listener.on_object_deleted(event) }
        .to change { Trophy.where(work_id: target_work_id).count }
        .from(1).to(0)

      expect(Trophy.where(work_id: 'other-work').count).to eq(1)
    end

    context 'when the event includes an object' do
      let(:payload) { { object: instance_double('resource', id: 'z890s9938') } }

      it 'deletes trophies using the object id' do
        expect { listener.on_object_deleted(event) }
          .to change { Trophy.where(work_id: target_work_id).count }
          .from(1).to(0)
      end
    end
  end
end
