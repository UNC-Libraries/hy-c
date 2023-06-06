# frozen_string_literal: true
require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe Tasks::SageNewArticleIngester, :sage, :ingest do
  let(:ingester) { described_class.new }
  let(:user) { FactoryBot.create(:admin) }

  let(:sage_fixture_path) { File.join(fixture_path, 'sage') }
  let(:first_package_identifier) { 'CCX_2021_28_10.1177_1073274820985792' }
  let(:first_xml_path) { "#{sage_fixture_path}/#{first_package_identifier}/10.1177_1073274820985792.xml" }
  let(:first_zip_path) { "spec/fixtures/sage/#{first_package_identifier}.zip" }
  let(:jats_ingest_work) { JatsIngestWork.new(xml_path: first_xml_path) }
  let(:unzipped_dir) { "#{sage_fixture_path}/#{first_package_identifier}/" }
  let(:deposit_record) { double() }
  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end
  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:status_service) { instance_double(Tasks::IngestStatusService) }
  let(:logger) { instance_double(Logger) }

  before do
    permission_template
    workflow
    ingester.package_file_names = Dir.entries(unzipped_dir)
    ingester.package_name = "#{first_package_identifier}.zip"
    ingester.jats_ingest_work = jats_ingest_work
    ingester.depositor = user
    ingester.unzipped_package_dir = unzipped_dir
    ingester.status_service = status_service
    ingester.logger = logger
    ingester.deposit_record = deposit_record
    ingester.admin_set = admin_set
    allow(logger).to receive(:info)
    allow(deposit_record).to receive(:id).and_return("deposit_record_id")
  end

  describe '#article_with_metadata' do
    it 'can create a valid article' do
      expect do
        ingester.article_with_metadata
      end.to change { Article.count }.by(1)
    end

    context 'with built article' do
      let(:built_article) { ingester.article_with_metadata }

      it 'returns a valid article' do
        expect(built_article).to be_instance_of Article
        expect(built_article.persisted?).to be true
        expect(built_article.valid?).to be true
        # These values are also tested via the edit form in spec/features/edit_sage_ingested_works_spec.rb
        expect(built_article.title).to eq(['Inequalities in Cervical Cancer Screening Uptake Between Chinese Migrant Women and Local Women: A Cross-Sectional Study'])
        first_creator = built_article.creators.find { |creator| creator[:index] == ['1'] }
        expect(first_creator.attributes['name']).to match_array(['Holt, Hunter K.'])
        expect(first_creator.attributes['other_affiliation']).to match_array(['Department of Family and Community Medicine, University of California, San Francisco, CA, USA'])
        expect(first_creator.attributes['orcid']).to match_array(['https://orcid.org/0000-0001-6833-8372'])
        expect(built_article.abstract).to include(/Efforts to increase education opportunities, provide insurance/)
        expect(built_article.date_issued).to eq('2021-02-01')
        expect(built_article.copyright_date).to eq('2021')
        expect(built_article.dcmi_type).to match_array(['http://purl.org/dc/dcmitype/Text'])
        expect(built_article.funder).to match_array(['Fogarty International Center'])
        expect(built_article.identifier).to match_array(['https://doi.org/10.1177/1073274820985792'])
        expect(built_article.issn).to match_array(['1073-2748'])
        expect(built_article.journal_issue).to be nil
        expect(built_article.journal_title).to eq('Cancer Control')
        expect(built_article.journal_volume).to eq('28')
        expect(built_article.keyword).to match_array(['HPV', 'HPV knowledge and awareness', 'cervical cancer screening', 'migrant women', 'China'])
        expect(built_article.license).to match_array(['http://creativecommons.org/licenses/by-nc/4.0/'])
        expect(built_article.license_label).to match_array(['Attribution-NonCommercial 4.0 International'])
        expect(built_article.publisher).to match_array(['SAGE Publications'])
        expect(built_article.resource_type).to match_array(['Article'])
        expect(built_article.rights_holder).to include(/SAGE Publications Inc, unless otherwise noted. Manuscript/)
        expect(built_article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
        expect(built_article.rights_statement_label).to eq('In Copyright')
        expect(built_article.visibility).to eq('open')
        expect(built_article.deposit_record).to be
      end

      it 'puts the work in an admin_set' do
        expect(built_article.admin_set).to be_instance_of(AdminSet)
        expect(built_article.admin_set.title).to eq(admin_set.title)
      end

      it 'attaches a pdf file_set to the article' do
        # ingester.extract_files(first_zip_path)
        expect do
          ingester.attach_file_set_to_work(work: built_article, file_path: File.join(unzipped_dir, '10.1177_1073274820985792.pdf'), user: user, visibility: 'open')
        end.to change { FileSet.count }.by(1)
        expect(built_article.file_sets).to be_instance_of(Array)
        fs = built_article.file_sets.first
        expect(fs).to be_instance_of(FileSet)
        expect(fs.depositor).to eq(user.uid)
        expect(fs.visibility).to eq(built_article.visibility)
        expect(fs.parent).to eq(built_article)
      end

      it 'attaches an xml file_set to the article' do
        # ingester.extract_files(first_zip_path)
        expect do
          ingester.attach_file_set_to_work(work: built_article, file_path: File.join(unzipped_dir, '10.1177_1073274820985792.xml'), user: user, visibility: 'restricted')
        end.to change { FileSet.count }.by(1)
        expect(built_article.file_sets).to be_instance_of(Array)
        fs = built_article.file_sets.first
        expect(fs).to be_instance_of(FileSet)
        expect(fs.depositor).to eq(user.uid)
        expect(fs.visibility).to eq('restricted')
        expect(fs.parent).to eq(built_article)
      end
    end
  end
end