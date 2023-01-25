# frozen_string_literal: true
require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe RemediateAffiliationsJob, type: :job do
  let(:unmappable_affiliations_path) { File.join(fixture_path, 'files', 'short_unmappable_affiliations.csv') }
  before do
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
  end
  around do |example|
    cached_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = cached_adapter
  end
  it 'enqueues jobs' do
    ActiveJob::Base.queue_adapter = :test
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('long_running_jobs')
  end

  it 'creates a new AffiliationRemediationService' do
    ActiveJob::Base.queue_adapter = :test
    allow(AffiliationRemediationService).to receive(:new).and_return(AffiliationRemediationService.new(unmappable_affiliations_path))
    described_class.perform_now
    expect(AffiliationRemediationService).to have_received(:new).with(Rails.root.join(ENV['DATA_STORAGE'], 'reports', 'unmappable_affiliations.csv').to_s)
  end
end
