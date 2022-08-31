# frozen_string_literal: true
require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe ReindexJob, type: :job do
  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  around do |example|
    cached_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = cached_adapter
  end

  it 'enqueues jobs' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('long_running_jobs')
  end
end
