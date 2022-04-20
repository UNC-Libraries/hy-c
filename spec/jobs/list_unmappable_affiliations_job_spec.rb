require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe ListUnmappableAffiliationsJob, type: :job do
  let(:csv_path) { "#{ENV['DATA_STORAGE']}/reports/unmappable_affiliations.csv" }
  after do
    FileUtils.remove_entry(csv_path) if File.exist?(csv_path)
  end
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

  it 'writes unmappable affiliations to a csv' do
    expect(File.exist?(csv_path)).to eq false
    described_class.perform_now
    expect(File.exist?(csv_path)).to eq true
  end
end
