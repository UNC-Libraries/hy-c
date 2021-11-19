# [hyc-override] updated to work in hyc and to verify uploaded file cleanup
require 'rails_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe CreateDerivativesJob do
  around do |example|
    # TODO: These tests behave surprisingly when TEMP_STORAGE and DATA_STORAGE are set to different properties
    # There seems to be some confusion in the code and tests between the upload_path and the working_path and their
    # connected environment variables.
    cached_temp_storage = ENV['TEMP_STORAGE']
    ENV['TEMP_STORAGE'] = temp_storage_path
    cached_data_storage = ENV['DATA_STORAGE']
    ENV['DATA_STORAGE'] = data_storage_path
    example.run
    ENV['TEMP_STORAGE'] = cached_temp_storage
    ENV['DATA_STORAGE'] = cached_data_storage
  end

  before do
    allow(Hyrax.config).to receive(:working_path).and_return(temp_storage_path)
    allow(Hyrax.config).to receive(:upload_path).and_return(->() { Pathname.new data_storage_path })
  end
  # Quoth the Hyrax config:
  # Location on local file system where uploaded files will be staged
  # prior to being ingested into the repository or having derivatives generated.
  let(:temp_storage_path) { File.join(fixture_path, "tmp") }

  # Quoth the Hyrax config: "Temporary paths to hold uploads before they are ingested into FCrepo"
  let(:data_storage_path) { File.join(fixture_path, "data") }

  context "with an audio file" do
    let(:id)       { '123' }
    let(:file_set) { FileSet.new }

    let(:test_file) do
      Hydra::PCDM::File.new.tap do |f|
        f.content = 'foo'
        f.original_name = 'picture.png'
        f.save!
      end
    end

    before do
      allow(FileSet).to receive(:find).with(id).and_return(file_set)
      allow(file_set).to receive(:id).and_return(id)
      allow(file_set).to receive(:mime_type).and_return('audio/x-wav')
    end

    let!(:working_file) { Hyrax::WorkingDirectory.find_or_retrieve(test_file.id, file_set.id) }

    context "with a file name" do
      it 'calls create_derivatives and save on a file set' do
        expect(Hydra::Derivatives::AudioDerivatives).to receive(:create)
        expect(file_set).to receive(:reload)
        expect(file_set).to receive(:update_index)
        described_class.perform_now(file_set, test_file.id)
        # Verify that the uploaded file was deleted
        expect(File.exist?(working_file)).to be false
        expect(File.exist?(File.dirname(working_file))).to be false
      end
    end

    context 'with a parent object' do
      before do
        allow(file_set).to receive(:parent).and_return(parent)
        # Stub out the actual derivative creation
        allow(file_set).to receive(:create_derivatives)
      end

      context 'when the file_set is the thumbnail of the parent' do
        let(:parent) { General.new(thumbnail_id: id) }

        it 'updates the index of the parent object' do
          expect(file_set).to receive(:reload)
          expect(parent).to receive(:update_index)
          described_class.perform_now(file_set, test_file.id)

          # Verify that the working file was deleted
          expect(File.exist?(working_file)).to be false
          expect(File.exist?(File.dirname(working_file))).to be false
        end
      end

      context "when the file_set isn't the parent's thumbnail" do
        let(:parent) { General.new }

        it "doesn't update the parent's index" do
          expect(file_set).to receive(:reload)
          expect(parent).not_to receive(:update_index)
          described_class.perform_now(file_set, test_file.id)

          # Verify that the working file was deleted
          expect(File.exist?(working_file)).to be false
          expect(File.exist?(File.dirname(working_file))).to be false
        end
      end
    end
  end

  context "with a pdf file" do
    let!(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false)}
    end
    let(:file_set) { FileSet.new }

    let(:temp_file_path) { File.join(fixture_path, "tmp/hyrax_test4.pdf") }

    let(:pdf_test_file) do
      Hydra::PCDM::File.new do |f|
        FileUtils.cp(File.join(fixture_path, "hyrax/hyrax_test4.pdf"), temp_file_path)
        f.content = File.open(temp_file_path)
        f.original_name = 'test.pdf'
        f.mime_type = 'application/pdf'
      end
    end

    before do
      file_set.apply_depositor_metadata user.user_key
      file_set.save!
      file_set.original_file = pdf_test_file
      file_set.save!
    end

    after do
      File.delete(temp_file_path) if File.exist?(temp_file_path)
    end

    let!(:working_file) { Hyrax::WorkingDirectory.find_or_retrieve(pdf_test_file.id, file_set.id) }

    it "runs a full text extract" do
      expect(Hydra::Derivatives::PdfDerivatives).to receive(:create)
        .with(/test\.pdf/, outputs: [{ label: :thumbnail,
                                       format: 'jpg',
                                       size: '338x493',
                                       url: String,
                                       layer: 0 }])
      expect(Hydra::Derivatives::FullTextExtract).to receive(:create)
        .with(/test\.pdf/, outputs: [{ url: RDF::URI, container: "extracted_text" }])
      described_class.perform_now(file_set, pdf_test_file.id)

      # Verify that the working file was deleted
      expect(File.exist?(working_file)).to be false
      expect(File.exist?(File.dirname(working_file))).to be false
    end
  end
end
