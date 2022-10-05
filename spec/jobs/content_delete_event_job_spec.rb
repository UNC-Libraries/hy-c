# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/jobs/content_delete_event_job_override.rb')

RSpec.describe ContentDeleteEventJob do
  let(:user) { FactoryBot.create(:user) }
  let(:mock_time) { Time.zone.at(1) }
  let(:event) do
    {
      action: "User <a href=\"/catalog?f%5Bdepositor_ssim%5D%5B%5D=#{user.uid}\">#{user.email}</a> has deleted object 'workid5'",
      timestamp: '1'
    }
  end

  before do
    allow(Time).to receive(:now).and_return(mock_time)
  end

  it 'produces event containing depositor search link' do
    expect do
      described_class.perform_now('workid5', user)
    end.to change { user.profile_events.length }.by(1)
    expect(user.profile_events.first).to eq(event)
  end
end
