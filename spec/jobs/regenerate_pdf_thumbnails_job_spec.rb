require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe RegeneratePdfThumbnailsJob, type: :job do
  let(:file_set_one) { FactoryBot.create(:file_set, :with_original_pdf_file) }
  let(:file_set_two) { FactoryBot.create(:file_set, :with_original_pdf_file) }
  let(:file_set_three) { FactoryBot.create(:file_set, :with_original_file) }

  before do
    # instantiate FileSets
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit

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
