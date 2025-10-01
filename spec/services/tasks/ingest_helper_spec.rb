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

  describe '#attach_pdf_to_work_with_file_path!' do
    let(:admin_user) { FactoryBot.create(:user, uid: 'admin') }
    let(:tmp_full_text_dir) { Dir.mktmpdir('fulltext') }
    let(:filename)          { 'PMC123_001.pdf' }
    let(:source_pdf)        { Rails.root.join('spec/fixtures/files/sample_pdf.pdf') }
    let(:dest_path)         { File.join(tmp_full_text_dir, filename) }

    before do
      admin_user # ensure depositor exists
      helper.instance_variable_set(:@full_text_path, tmp_full_text_dir)
      FileUtils.cp(source_pdf, dest_path)
      work.save!
    end

    after do
      FileUtils.remove_entry_secure(tmp_full_text_dir) if File.exist?(tmp_full_text_dir)
    end

    it 'attaches a FileSet from a file path and returns the FileSet' do
      record = { 'ids' => { 'work_id' => work.id } }

      # let the helper call the real attach method so we assert behavior
      allow(helper).to receive(:attach_pdf_to_work).and_call_original

      file_set = helper.attach_pdf_to_work_with_file_path!(record, dest_path, 'admin')

      expect(File.exist?(dest_path)).to be true
      expect(file_set).to be_a(FileSet)
      expect(file_set.read_groups).to include('public')

      # verify it attached the file we passed in and used admin depositor visibility
      expect(helper).to have_received(:attach_pdf_to_work).with(
        an_instance_of(Article),
        dest_path,
        admin_user,
        work.visibility
      )
    end

    it 'raises when no depositor user exists' do
      User.where(uid: 'admin').delete_all
      record = { 'ids' => { 'work_id' => work.id } }

      expect {
        helper.attach_pdf_to_work_with_file_path!(record, dest_path, 'admin')
      }.to raise_error(RuntimeError, 'No depositor found')
    end

    it 'raises ArgumentError when work_id is missing' do
      record = { 'ids' => {} }

      expect {
        helper.attach_pdf_to_work_with_file_path!(record, dest_path, 'admin')
      }.to raise_error(ArgumentError, 'No article ID found to attach PDF')
    end
  end

  describe '#sync_permissions_and_state!' do
    let(:admin_user) { FactoryBot.create(:user, uid: 'admin') }
    let(:admin_set) { FactoryBot.create(:admin_set) }
    let(:workflow) do
      # create a workflow + deposited state like Hyrax expects
      permission_template = Hyrax::PermissionTemplate.find_or_create_by!(source_id: admin_set.id)
      Sipity::Workflow.create!(permission_template: permission_template, active: true, name: 'default') do |wf|
        Sipity::WorkflowState.create!(workflow: wf, name: 'deposited')
      end
    end

    let(:work) { FactoryBot.create(:article, admin_set: admin_set, depositor: admin_user.uid) }

    before do
      workflow # ensure workflow + state exist
      helper.instance_variable_set(:@config, { 'depositor_onyen' => 'admin' })
    end

    context 'when work has no Sipity entity' do
      it 'creates the entity and sets it to deposited' do
        helper.sync_permissions_and_state!(work.id, 'admin')

        entity = Sipity::Entity.find_by(proxy_for_global_id: work.to_global_id.to_s)
        expect(entity).not_to be_nil
        expect(entity.workflow).to eq(workflow)
        expect(entity.workflow_state.name).to eq('deposited')
      end
    end

    context 'when work already has a non-deposited state' do
      let!(:existing_entity) do
        Sipity::Entity.create!(
          proxy_for_global_id: work.to_global_id.to_s,
          workflow: workflow,
          workflow_state: Sipity::WorkflowState.create!(workflow: workflow, name: 'draft')
        )
      end

      it 'updates the state to deposited' do
        helper.sync_permissions_and_state!(work.id, 'admin')

        expect(existing_entity.reload.workflow_state.name).to eq('deposited')
      end
    end
  end
end
