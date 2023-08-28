# frozen_string_literal: true
require 'rails_helper' 
require Rails.root.join('app/overrides/jobs/change_depositor_event_job_override.rb')

RSpec.describe ChangeDepositorEventJob do
  let(:user) { FactoryBot.create(:user) }
  let(:previous_user) { FactoryBot.create(:user) }
  let(:work) { FactoryBot.create(:work, user: user, proxy_depositor: previous_user.user_key) }
  let(:mock_time) { Time.zone.at(1) }
  let(:event) do
    { action: "User <a href=\"/catalog?f%5Bdepositor_ssim%5D%5B%5D=#{previous_user.uid}\">#{previous_user.user_key}</a> " \
                          "has transferred <a href=\"/concern/generals/#{work.id}\">Test title</a> " \
                          "to user <a href=\"/catalog?f%5Bdepositor_ssim%5D%5B%5D=#{user.uid}\">#{user.email}</a>",
      timestamp: '1' }
  end

  before do
    allow(Time).to receive(:now).and_return(mock_time)
  end

  it "logs the event containing user search link to the proxy and depositor's profile, and the Work" do
    expect do
      described_class.perform_now(work)
    end.to change { user.events.length }.by(1)
          .and change { previous_user.profile_events.length }.by(1)
          .and change { work.events.length }.by(1)

    expect(user.events.first).to eq(event)
    expect(previous_user.profile_events.first).to eq(event)
    expect(work.events.first).to eq(event)
  end
end
