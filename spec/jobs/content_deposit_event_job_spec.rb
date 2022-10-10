# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/jobs/content_deposit_event_job_override.rb')

RSpec.describe ContentDepositEventJob do
  let(:user) { FactoryBot.create(:user) }
  let(:curation_concern) { FactoryBot.create(:work) }
  let(:mock_time) { Time.zone.at(1) }
  let(:event) do
    {
      action: "User <a href=\"/catalog?f%5Bdepositor_ssim%5D%5B%5D=#{user.uid}\">#{user.email}</a> has deposited <a href=\"/concern/generals/#{curation_concern.id}\">Test title</a>",
      timestamp: '1'
    }
  end

  before do
    allow(Time).to receive(:now).and_return(mock_time)
  end

  it 'produces event containing user search link' do
    expect do
      described_class.perform_now(curation_concern, user)
    end.to change { user.profile_events.length }.by(1)
                                                .and change { curation_concern.events.length }.by(1)

    expect(user.profile_events.first).to eq(event)
    expect(curation_concern.events.first).to eq(event)
  end
end
