require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe RegeneratePdfThumbnailsJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_pdf_file) }
  let(:file_set_two) { FactoryBot.create(:file_set, :with_original_pdf_file) }
  let(:file_set_three) { FactoryBot.create(:file_set, :with_original_file) }

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
  end

  it 'finds all the FileSets that include pdfs' do
    expect(described_class.perform_now).to eq([file_set_one.id, file_set_two.id])
  end

  it 'calls the CreateDerivativesJob on those file sets' do
    expect(Hydra::Derivatives::PdfDerivatives).to receive(:create).exactly(2).times
    described_class.perform_now
  end
end
