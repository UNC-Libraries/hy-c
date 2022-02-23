require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe CreatePdfThumbnailJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_pdf_file) }
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
    expect(Hydra::Derivatives::PdfDerivatives).to receive(:create)
    described_class.perform_now(file_set_id: file_set_one.id)
  end

  it 'stops processing if the FileSet and file are not pdfs' do
    ActiveJob::Base.queue_adapter = :inline
    expect(Hydra::Derivatives::PdfDerivatives).not_to receive(:create)
    described_class.perform_now(file_set_id: file_set_three.id)
  end

  it 'runs the job without errors' do
    ActiveJob::Base.queue_adapter = :inline
    described_class.perform_now(file_set_id: file_set_one.id)
  end

  it 'only creates a thumbnail for the pdf file' do
    ActiveJob::Base.queue_adapter = :inline
    pdf_temp_path = /sample_pdf.pdf/
    text_temp_path = /test.txt/
    expect(Hydra::Derivatives::PdfDerivatives).to receive(:create).with(pdf_temp_path, any_args)
    expect(Hydra::Derivatives::PdfDerivatives).not_to receive(:create).with(text_temp_path, any_args)
    described_class.perform_now(file_set_id: file_set_with_extracted_text.id)
  end

  describe 'with a pdf with unexpected info' do
    let(:file_set) { FactoryBot.create(:file_set, :with_malformed_pdf) }

    # This test currently fails in CI.
    # This test passes either when Rails.configuration.eager_load = true, which makes many other tests fail;
    # or when app/lib/mini_magick/image/info.rb is moved to the lib directory, in which case it doesn't get picked up in production
    xit 'runs the job and logs errors' do
      ActiveJob::Base.queue_adapter = :inline
      allow(Rails.logger).to receive(:warn)
      described_class.perform_now(file_set_id: file_set.id)
      expect(Rails.logger).to have_received(:warn).with('Error logged for image:    **** Error: /BBox has zero width or height, which is not allowed.                Output may be incorrect.')
    end
  end
end
