# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/models/concerns/bulkrax/file_factory_override.rb')

RSpec.describe Bulkrax::FileFactory do
  include Bulkrax::FileFactory

  let!(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false) }
  end
  let(:klass) { Article }
  let(:attributes) { {} }
  let(:object) { {} }
  let(:file_set) { FileSet.new }
  let(:temp_pdf_path) { File.join(fixture_path, 'tmp', 'hyrax_test4.pdf') }

  let(:file) do
    Hydra::PCDM::File.new do |f|
      f.content = File.open(temp_pdf_path)
      f.original_name = 'test.pdf'
      f.mime_type = 'application/pdf'
    end
  end

  before do
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    FileUtils.cp(File.join(fixture_path, 'hyrax/hyrax_test4.pdf'), temp_pdf_path)

    file_set.apply_depositor_metadata user.user_key
    file_set.save!
    file_set.original_file = file
    file_set.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    file_set.save!

    allow(new_remote_files).to receive(:present?).and_return(false)
    allow(::CreateDerivativesJob).to receive(:set).with(wait: 1.minute).and_return(::CreateDerivativesJob)
    allow(::CreateDerivativesJob).to receive(:perform_later).with(file_set, file.id).and_return(file_set)
  end

  after do
    file_set.destroy!
  end

  let(:local_file_sets) { [file_set] }

  it 'leaves updated files with their current access level' do
    file_attributes(true)
    set_removed_filesets
    expect(file_set.visibility).to eq(Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC)
    expect(file_set.files.first.mime_type).to eq('application/pdf')
  end

  it 'marks replaced files as private' do
    file_attributes
    set_removed_filesets
    expect(file_set.visibility).to eq(Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    expect(file_set.files.first.mime_type).to eq('application/pdf')
  end
end
