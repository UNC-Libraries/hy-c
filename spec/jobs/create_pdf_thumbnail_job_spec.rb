require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe CreatePdfThumbnailJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_pdf_file) }
  let(:file_set_three) { FactoryBot.create(:file_set, :with_original_file) }

  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  it 'enqueues jobs' do
    ActiveJob::Base.queue_adapter = :test
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('import')
  end

  it 'calls the CreateDerivativesJob on those file sets' do
    ActiveJob::Base.queue_adapter = :inline
    expect(Hydra::Derivatives::PdfDerivatives).to receive(:create)
    described_class.perform_now(file_set_id: file_set_one.id, file_id: file_set_one.files.first.id)
  end

  it 'stops processing if the FileSet and file are not pdfs' do
    ActiveJob::Base.queue_adapter = :inline
    expect(Hydra::Derivatives::PdfDerivatives).not_to receive(:create)
    described_class.perform_now(file_set_id: file_set_three.id, file_id: file_set_three.files.first.id)
  end

  context 'with version information on the file' do
    let(:file_id_solr) { "#{file_set_one.files.first.id}/fcr:versions/version1" }

    it 'matches the file_id if it has version information at the end' do
      ActiveJob::Base.queue_adapter = :inline
      expect(Hydra::Derivatives::PdfDerivatives).to receive(:create)
      described_class.perform_now(file_set_id: file_set_one.id, file_id: file_id_solr)
    end
  end
end
