# [hyc-override] updated to work in hyc and to verify uploaded file cleanup
require 'rails_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe CreateDerivativesJob do
  around do |example|
    ffmpeg_enabled = Hyrax.config.enable_ffmpeg
    Hyrax.config.enable_ffmpeg = true
    example.run
    Hyrax.config.enable_ffmpeg = ffmpeg_enabled
  end

  context "with an audio file" do
    let(:id)       { '123' }
    let(:file_set) { FileSet.new }

    let(:file) do
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
    
    let!(:upload_file) { Hyrax::WorkingDirectory.find_or_retrieve(file.id, file_set.id) }

    context "with a file name" do
      it 'calls create_derivatives and save on a file set' do
        expect(Hydra::Derivatives::AudioDerivatives).to receive(:create)
        expect(file_set).to receive(:reload)
        expect(file_set).to receive(:update_index)
        described_class.perform_now(file_set, file.id)
        
        # Verify that the uploaded file was deleted
        expect(File.exist?(upload_file)).to be false
        expect(File.exist?(File.dirname(upload_file))).to be false
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
          described_class.perform_now(file_set, file.id)
          
          # Verify that the uploaded file was deleted
          expect(File.exist?(upload_file)).to be false
          expect(File.exist?(File.dirname(upload_file))).to be false
        end
      end

      context "when the file_set isn't the parent's thumbnail" do
        let(:parent) { General.new }

        it "doesn't update the parent's index" do
          expect(file_set).to receive(:reload)
          expect(parent).not_to receive(:update_index)
          described_class.perform_now(file_set, file.id)
          
          # Verify that the uploaded file was deleted
          expect(File.exist?(upload_file)).to be false
          expect(File.exist?(File.dirname(upload_file))).to be false
        end
      end
    end
  end

  context "with a pdf file" do
    let!(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false)}
    end
    let(:file_set) { FileSet.new }
    let(:temp_pdf_path) { File.join(fixture_path, "tmp", "hyrax_test4.pdf") }

    let(:file) do
      Hydra::PCDM::File.new do |f|
        f.content = File.open(temp_pdf_path)
        f.original_name = 'test.pdf'
        f.mime_type = 'application/pdf'
      end
    end

    before do
      FileUtils.cp(File.join(fixture_path, "hyrax/hyrax_test4.pdf"), temp_pdf_path)
      file_set.apply_depositor_metadata user.user_key
      file_set.save!
      file_set.original_file = file
      file_set.save!
    end

    after do
      File.delete(temp_pdf_path) if File.exist?(temp_pdf_path)
    end

    let!(:upload_file) { Hyrax::WorkingDirectory.find_or_retrieve(file.id, file_set.id) }

    it "runs a full text extract" do
      expect(Hydra::Derivatives::PdfDerivatives).to receive(:create)
        .with(/test\.pdf/, outputs: [{ label: :thumbnail,
                                       format: 'jpg',
                                       size: '338x493',
                                       url: String,
                                       layer: 0 }])
      expect(Hydra::Derivatives::FullTextExtract).to receive(:create)
        .with(/test\.pdf/, outputs: [{ url: RDF::URI, container: "extracted_text" }])
      described_class.perform_now(file_set, file.id)
      
      # Verify that the uploaded file was deleted
      expect(File.exist?(upload_file)).to be false
      expect(File.exist?(File.dirname(upload_file))).to be false
    end
  end
end
