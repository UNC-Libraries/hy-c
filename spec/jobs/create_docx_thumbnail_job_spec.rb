require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe CreateDocxThumbnailJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_docx_file) }
  let(:file_set_two) { FactoryBot.create(:file_set, :with_original_msword_file) }
  let(:file_set_three) { FactoryBot.create(:file_set, :with_original_file) }
  let(:file_set_with_extracted_text) { FactoryBot.create(:file_set, :with_extracted_text) }

  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  context 'running the tests with the test queue adapter' do
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


  it 'calls the CreateDerivativesJob on those file sets' do
    expect(Hydra::Derivatives::DocumentDerivatives).to receive(:create)
    described_class.perform_now(file_set_id: file_set_one.id)
  end

  it 'stops processing if the FileSet and file are not docx files' do
    expect(Hydra::Derivatives::DocumentDerivatives).not_to receive(:create)
    described_class.perform_now(file_set_id: file_set_three.id)
  end

  it 'runs the job without errors' do
    described_class.perform_now(file_set_id: file_set_one.id)
  end

  context 'with an msword document' do
    it 'runs the job without errors' do
      described_class.perform_now(file_set_id: file_set_two.id)
    end
  end
end
