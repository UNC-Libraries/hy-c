require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe CreateDocxThumbnailJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_docx_file) }
  let(:file_set_three) { FactoryBot.create(:file_set, :with_original_file) }
  let(:file_set_with_extracted_text) { FactoryBot.create(:file_set, :with_extracted_text) }

  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  it 'enqueues jobs' do
    ActiveJob::Base.queue_adapter = :test
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('long_running_jobs')
  end

  it 'calls the CreateDerivativesJob on those file sets' do
    ActiveJob::Base.queue_adapter = :inline
    expect(Hydra::Derivatives::DocumentDerivatives).to receive(:create)
    described_class.perform_now(file_set_id: file_set_one.id)
  end

  it 'stops processing if the FileSet and file are not docx files' do
    ActiveJob::Base.queue_adapter = :inline
    expect(Hydra::Derivatives::DocumentDerivatives).not_to receive(:create)
    described_class.perform_now(file_set_id: file_set_three.id)
  end

  it 'runs the job without errors' do
    ActiveJob::Base.queue_adapter = :inline
    described_class.perform_now(file_set_id: file_set_one.id)
  end
end
