# frozen_string_literal: true
# spec/helpers/tasks/ingest_helper_spec.rb
require 'rails_helper'

RSpec.describe Tasks::IngestHelper do
  let(:helper) do
    Class.new { include Tasks::IngestHelper }.new
  end

  let(:user) { FactoryBot.create(:admin) }
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:work) { Article.new(title: ['Test Work'], depositor: user.uid, admin_set: admin_set) }
  let(:file_path) { Rails.root.join('spec/fixtures/files/sample_pdf.pdf') }
  let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }

  before do
    allow(WorkUtilsHelper).to receive(:get_permissions_attributes).with(admin_set.id)
      .and_return([{ access: 'read', type: 'group', name: 'public' }])

    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    allow(CharacterizeJob).to receive(:perform_later)
  end

  describe '#attach_file_set_to_work' do
    it 'attaches a FileSet and applies permissions' do
      file_set = helper.attach_file_set_to_work(
        work: work,
        file_path: file_path,
        user: user,
        visibility: visibility
      )

      expect(work).to be_persisted
      expect(file_set).to be_a(FileSet)
      expect(file_set.read_groups).to include('public')
    end

    it 'returns nil and logs when the source file is missing' do
      missing_path = Rails.root.join('spec/fixtures/files/does_not_exist.pdf')

      allow(Rails.logger).to receive(:error)
      allow(LogUtilsHelper).to receive(:double_log)

      result = helper.attach_file_set_to_work(
        work: work,
        file_path: missing_path,
        user: user,
        visibility: visibility
      )

      expect(result).to be_nil

      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including("Error attaching FileSet to work #{work.id}"),
        :error,
        tag: 'FileSetAttach'
      )

      # The rescue block logs a second error line including file_path
      expect(Rails.logger).to have_received(:error).with(
        a_string_including('file_path')
      ).at_least(:once)
    end

  end

  describe '#attach_pdf_to_work_with_binary!' do
    let(:tmp_full_text_dir) { Dir.mktmpdir('fulltext') }
    let(:pdf_binary)        { File.binread(file_path) }
    let(:filename)          { 'PMC123_001.pdf' }
    let(:admin_user)        { FactoryBot.create(:user, uid: 'admin') }

    before do
      helper.instance_variable_set(:@full_text_path, tmp_full_text_dir)
      admin_user # create the admin user
    end

    after do
      FileUtils.remove_entry_secure(tmp_full_text_dir) if File.exist?(tmp_full_text_dir)
    end

    it 'writes the PDF to disk, attaches a FileSet, and returns [file_set, basename]' do
      work.save!
      record = { 'ids' => { 'work_id' => work.id } }

      allow(helper).to receive(:attach_pdf_to_work).and_call_original

      file_set, basename = helper.attach_pdf_to_work_with_binary!(record, pdf_binary, filename)

      full_path = File.join(tmp_full_text_dir, filename)
      expect(File.exist?(full_path)).to be true
      expect(basename).to eq(filename)

      expect(file_set).to be_a(FileSet)
      expect(file_set.read_groups).to include('public')

      expect(helper).to have_received(:attach_pdf_to_work).with(
        an_instance_of(Article),
        full_path,
        admin_user,
        work.visibility
      )
    end

    it 'raises when no depositor user exists' do
      # Remove the admin user so the lookup fails
      User.where(uid: 'admin').delete_all

      work.save!
      record = { 'ids' => { 'work_id' => work.id } }

      expect {
        helper.attach_pdf_to_work_with_binary!(record, pdf_binary, filename)
      }.to raise_error(RuntimeError, 'No depositor found')
    end

    it 'raises ArgumentError when work_id is missing' do
      record = { 'ids' => { } }
      expect {
        helper.attach_pdf_to_work_with_binary!(record, pdf_binary, filename)
      }.to raise_error(ArgumentError, 'No article ID found to attach PDF')
    end
  end

end
