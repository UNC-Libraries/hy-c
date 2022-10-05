# frozen_string_literal: true
require 'rails_helper'
# require Rails.root.join('app/overrides/jobs/content_update_event_job_override.rb')

RSpec.describe ContentUpdateEventJob do
  let(:user) { FactoryBot.create(:user) }
  let(:mock_time) { Time.zone.at(1) }
  let(:file_set) { FactoryBot.create(:file_set) }
  let(:event) do
    {
      action: "User <a href=\"/catalog?f%5Bdepositor_ssim%5D%5B%5D=#{user.uid}\">#{user.email}</a> " \
              "has updated <a href=\"/concern/file_sets/#{file_set.id}\">Test fileset</a>",
      timestamp: '1'
    }
  end

  before do
    allow(Time).to receive(:now).at_least(:once).and_return(mock_time)
    file_set.title = ['Test fileset']
  end

  it "logs the event containing link to search to the depositor's profile and the FileSet" do
    expect do
      described_class.perform_now(file_set, user)
    end.to change { user.profile_events.length }.by(1)
          .and change { file_set.events.length }.by(1)

    expect(user.profile_events.first).to eq(event)
    expect(file_set.events.first).to eq(event)
  end
end