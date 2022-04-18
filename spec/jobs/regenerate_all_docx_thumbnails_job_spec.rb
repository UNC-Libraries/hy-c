require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe RegenerateAllDocxThumbnailsJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_docx_file) }
  let(:file_set_two) { FactoryBot.create(:file_set, :with_original_docx_file) }
  let(:file_set_three) { FactoryBot.create(:file_set, :with_original_file) }
  let(:file_set_with_extracted_text) { FactoryBot.create(:file_set, :with_extracted_text) }

  before do
    # Clean out index so we only find our example files
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
    # Mock virus checker so it passes in CI
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
    # instantiate FileSets
    file_set_one
    file_set_two
    file_set_three
    file_set_with_extracted_text
  end

  context 'with the test queue adapter' do
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
    expect(Hydra::Derivatives::DocumentDerivatives).to receive(:create).exactly(2).times
    described_class.perform_now
  end
end
