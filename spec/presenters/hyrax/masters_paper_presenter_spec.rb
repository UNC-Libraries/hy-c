# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

RSpec.describe Hyrax::MastersPaperPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { 'id' => '888888',
      'title_tesim' => ['foo'],
      'human_readable_type_tesim' => ['MastersPaper'],
      'has_model_ssim' => ['MastersPaper'],
      'creator_display_tesim' => ['a creator'],
      'date_created_tesim' => ['an unformatted date'],
      'depositor_tesim' => user_key,
      'resource_type_tesim' => ['a type'],
      'abstract_tesim' => ['an abstract'],
      'academic_concentration_tesim' => ['a concentration'],
      'access_right_tesim' => 'access',
      'advisor_display_tesim' => ['an advisor'],
      'date_issued_tesim' => ['a date'],
      'dcmi_type_tesim' => ['science fiction'],
      'degree_tesim' => 'degree',
      'degree_granting_institution_tesim' => 'an institution',
      'deposit_record_tesim' => 'a deposit record',
      'doi_tesim' => '12345',
      'extent_tesim' => ['extent'],
      'based_near_tesim' => ['a subject'],
      'graduation_year_tesim' => '2017',
      'note_tesim' => ['a note', 'another note'],
      'reviewer_display_tesim' => ['a reviewer'],
      'rights_notes_tesim' => ['a rights note'],
      'language_label_tesim' => ['language'],
      'license_label_tesim' => ['license'],
      'rights_statement_label_tesim' => 'rights'
    }
  end
  let(:ability) { nil }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  subject { described_class.new(double, double) }

  it { is_expected.to delegate_method(:to_s).to(:solr_document) }
  it { is_expected.to delegate_method(:human_readable_type).to(:solr_document) }
  it { is_expected.to delegate_method(:creator_display).to(:solr_document) }
  it { is_expected.to delegate_method(:date_created).to(:solr_document) }
  it { is_expected.to delegate_method(:date_modified).to(:solr_document) }
  it { is_expected.to delegate_method(:date_uploaded).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement).to(:solr_document) }
  it { is_expected.to delegate_method(:based_near_label).to(:solr_document) }
  it { is_expected.to delegate_method(:related_url).to(:solr_document) }
  it { is_expected.to delegate_method(:depositor).to(:solr_document) }
  it { is_expected.to delegate_method(:identifier).to(:solr_document) }
  it { is_expected.to delegate_method(:resource_type).to(:solr_document) }
  it { is_expected.to delegate_method(:keyword).to(:solr_document) }
  it { is_expected.to delegate_method(:itemtype).to(:solr_document) }

  it { is_expected.to delegate_method(:abstract).to(:solr_document) }
  it { is_expected.to delegate_method(:academic_concentration).to(:solr_document) }
  it { is_expected.to delegate_method(:access_right).to(:solr_document) }
  it { is_expected.to delegate_method(:advisor_display).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:degree).to(:solr_document) }
  it { is_expected.to delegate_method(:degree_granting_institution).to(:solr_document) }
  it { is_expected.to delegate_method(:deposit_record).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:graduation_year).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:reviewer_display).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_notes).to(:solr_document) }
  it { is_expected.to delegate_method(:language_label).to(:solr_document) }
  it { is_expected.to delegate_method(:license_label).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement_label).to(:solr_document) }

  describe '#model_name' do
    subject { presenter.model_name }

    it { is_expected.to be_kind_of ActiveModel::Name }
  end

  describe '#attribute_to_html' do
    let(:renderer) { double('renderer') }

    context 'with an existing field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:title, ['foo'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:title)
      end
    end

    context 'with a custom abstract field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:abstract, ['an abstract'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:abstract)
      end
    end

    context 'with a custom academic_concentration field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:academic_concentration, ['a concentration'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:academic_concentration)
      end
    end

    context 'with a custom access_right field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:access_right, ['access'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:access_right)
      end
    end

    context 'with a custom advisor_display field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:advisor_display, ['an advisor'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:advisor_display)
      end
    end

    context 'with a custom creator_display field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:creator_display, ['a creator'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:creator_display)
      end
    end

    context 'with a custom date_issued field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, ['a date'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
      end
    end

    context 'with a custom degree field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:degree, 'degree', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:degree)
      end
    end

    context 'with a custom degree_granting_institution field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:degree_granting_institution, 'an institution', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:degree_granting_institution)
      end
    end

    context 'with a custom deposit_record field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:deposit_record, 'a deposit record', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:deposit_record)
      end
    end

    context 'with a custom doi field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:doi, '12345', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:doi)
      end
    end

    context 'with a custom extent field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:extent, ['extent'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:extent)
      end
    end

    context 'with a custom dcmi_type field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:dcmi_type, ['science fiction'], {}).and_return(renderer)
      end
      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:dcmi_type)
      end
    end

    context 'with a custom graduation_year field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:graduation_year, '2017', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:graduation_year)
      end
    end

    context 'with a custom note field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:note, ['a note', 'another note'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:note)
      end
    end

    context 'with a custom reviewer_display field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:reviewer_display, ['a reviewer'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:reviewer_display)
      end
    end

    context 'with a custom resource_type field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:resource_type, ['a type'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:resource_type)
      end
    end

    context 'with a custom rights_notes field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_notes, ['a rights note'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_notes)
      end
    end

    context 'with a custom language label field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:language_label, ['language'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:language_label)
      end
    end

    context 'with a custom license label field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:license_label, ['license'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:license_label)
      end
    end

    context 'with a custom rights statement label field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_statement_label, 'rights', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_statement_label)
      end
    end

    context "with a field that doesn't exist" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:something, 'foo', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).not_to receive(:render)
      end
    end
  end

  describe '#scholar?' do
    it 'returns true' do
      expect(presenter.scholarly?).to be_truthy
    end
  end
end
