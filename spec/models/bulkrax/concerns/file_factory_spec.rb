# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/models/concerns/bulkrax/file_factory_override.rb')

RSpec.describe Bulkrax::FileFactory do
  include Bulkrax::FileFactory

  after do
    ActiveFedora::Cleaner.clean!
  end

  let!(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test') do |u|
      u.save!(validate: false)
    end
  end

  let(:file_set) { FileSet.new }
  let(:fixture_path) { RSpec.configuration.fixture_paths }
  let(:temp_pdf_path) { File.join(fixture_path, 'tmp', 'hyrax_test4.pdf') }

  let(:file) do
    Hydra::PCDM::File.new do |f|
      f.content = File.open(temp_pdf_path)
      f.original_name = 'test.pdf'
      f.mime_type = 'application/pdf'
    end
  end

  before do
    ActiveFedora::Cleaner.clean!
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?).and_return(false)
    FileUtils.cp(File.join(fixture_path, 'hyrax/hyrax_test4.pdf'), temp_pdf_path)

    file_set.apply_depositor_metadata user.user_key
    file_set.save!

    file_set.original_file = file
    file_set.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    file_set.save!

    allow(::CreateDerivativesJob).to receive(:set).with(wait: 1.minute).and_return(::CreateDerivativesJob)
    allow(::CreateDerivativesJob).to receive(:perform_later)
  end

  after do
    file_set.destroy!
  end

  it 'leaves updated files with their current access level' do
    # The upstream implementation uses @update_files to determine whether
    # the file set should remain public.
    @update_files = true
    remove_file_set(file_set: file_set)

    expect(file_set.visibility).to eq(Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC)
    expect(file_set.files.first.mime_type).to eq('application/pdf')
  end

  it 'marks replaced files as private' do
    @update_files = false
    remove_file_set(file_set: file_set)

    expect(file_set.visibility).to eq(Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    expect(file_set.files.first.mime_type).to eq('application/pdf')
  end
end
