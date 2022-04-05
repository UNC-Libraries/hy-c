require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe ListFileSetsWithoutFilesJob, type: :job do
  let(:csv_path) { "#{ENV['DATA_STORAGE']}/reports/file_sets_without_files.csv" }
  after do
    FileUtils.remove_entry(csv_path) if File.exist?(csv_path)
  end
  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  it 'enqueues jobs' do
    ActiveJob::Base.queue_adapter = :test
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('long_running_jobs')
  end

  it 'writes FileSets without files to a csv' do
    ActiveJob::Base.queue_adapter = :test
    expect(File.exist?(csv_path)).to eq false
    described_class.perform_now
    expect(File.exist?(csv_path)).to eq true
  end
end
