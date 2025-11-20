# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::IngestHelper do
  let(:helper) do
    Class.new { include Tasks::IngestHelperUtils::IngestHelper }.new
  end

  let(:user) { FactoryBot.create(:admin) }
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['Test Admin Set']) }
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

      file_set = helper.attach_pdf_to_work_with_file_path!(record: record,
                                                           file_path: dest_path,
                                                           depositor_onyen: 'admin')

      expect(File.exist?(dest_path)).to be true
      expect(file_set).to be_a(FileSet)
      expect(file_set.read_groups).to include('public')

      # verify it attached the file we passed in and used admin depositor visibility
      expect(helper).to have_received(:attach_pdf_to_work).with(
        work: an_instance_of(Article),
        file_path: dest_path,
        depositor: admin_user,
        visibility: work.visibility
      )
    end

    it 'raises when no depositor user exists' do
      User.where(uid: 'admin').delete_all
      record = { 'ids' => { 'work_id' => work.id } }

      expect {
        helper.attach_pdf_to_work_with_file_path!(record: record,
                                                  file_path: dest_path,
                                                  depositor_onyen: 'admin')
      }.to raise_error(RuntimeError, 'No depositor found')
    end

    it 'raises ArgumentError when work_id is missing' do
      record = { 'ids' => {} }

      expect {
        helper.attach_pdf_to_work_with_file_path!(record: record,
                                                  file_path: dest_path,
                                                  depositor_onyen: 'admin')
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

    let(:work) do
      double('Article',
        id: 'test-work-123',
        to_global_id: double('GlobalID', to_s: 'gid://app/Article/test-work-123'),
        admin_set: admin_set,
        admin_set_id: admin_set.id,
        'permissions_attributes=': nil,
        save!: true,
        reload: nil,
        update_index: nil
      )
    end

    before do
      workflow # ensure workflow + state exist
      helper.instance_variable_set(:@config, { 'depositor_onyen' => 'admin' })
      allow(Article).to receive(:find).with(work.id).and_return(work)
    end

    context 'when work has no Sipity entity' do
      it 'creates the entity and sets it to deposited' do
        helper.sync_permissions_and_state!(work_id: work.id, depositor_uid: 'admin', admin_set: admin_set)

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
        helper.sync_permissions_and_state!(work_id: work.id, depositor_uid: 'admin', admin_set: admin_set)

        expect(existing_entity.reload.workflow_state.name).to eq('deposited')
      end
    end
  end

  describe '#new_article' do
    let(:pubmed_xml_doc) { Nokogiri::XML(sample_pubmed_xml) }
    let(:pubmed_article) { pubmed_xml_doc.xpath('//PubmedArticle').first }
    let(:mock_article) { double('article', visibility: nil, 'visibility=': nil) }
    let(:mock_builder) { double('builder', populate_article_metadata: true) }
    let(:sample_pubmed_xml) do
      <<~XML
        <?xml version="1.0"?>
        <PubmedArticleSet>
          <PubmedArticle>
            <MedlineCitation>
              <PMID Version="1">123456</PMID>
              <Article>
                <ArticleTitle>Sample Article Title</ArticleTitle>
              </Article>
            </MedlineCitation>
            <PubmedData>
              <ArticleIdList>
                <ArticleId IdType="pubmed">123456</ArticleId>
                <ArticleId IdType="pmc">PMC789012</ArticleId>
                <ArticleId IdType="doi">10.1000/example1</ArticleId>
              </ArticleIdList>
            </PubmedData>
          </PubmedArticle>
        </PubmedArticleSet>
      XML
    end

    before do
      allow(Article).to receive(:new).and_return(mock_article)
      allow(mock_article).to receive(:save!)
      allow(mock_article).to receive(:id).and_return('mock_id_123')
      allow(helper).to receive(:sync_permissions_and_state!)
    end

    it 'creates new article with private visibility' do
      config = { 'depositor_onyen' => 'test_user', 'admin_set_title' => 'Test Admin Set' }
      result = helper.send(:new_article, metadata: pubmed_article, config: {}, attr_builder: mock_builder)

      expect(Article).to have_received(:new)
      expect(mock_article).to have_received(:visibility=).with(
        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      )
      expect(mock_builder).to have_received(:populate_article_metadata)
      expect(result).to eq(mock_article)
    end
  end
end
