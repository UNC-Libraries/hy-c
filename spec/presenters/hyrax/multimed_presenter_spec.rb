# Generated via
#  `rails generate hyrax:work Multimed`
require 'rails_helper'

RSpec.describe Hyrax::MultimedPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { "id" => '888888',
      "title_tesim" => ['foo'],
      "human_readable_type_tesim" => ["Multimed"],
      "has_model_ssim" => ["Multimed"],
      "creator_display_tesim" => ['a creator'],
      "date_created_tesim" => ['an unformatted date'],
      "date_issued_tesim" => '2017-01-22',
      "depositor_tesim" => user_key,
      "abstract_tesim" => ['an abstract'],
      "dcmi_type_tesim" => ['science fiction'],
      "deposit_record_tesim" => 'a deposit record',
      "digital_collection_tesim" => ['my collection'],
      "doi_tesim" => '12345',
      "extent_tesim" => ['1999'],
      "based_near_tesim" => ['Italy'],
      "medium_tesim" => ['a medium'],
      "note_tesim" => ['a note'],
      "resource_type_tesim" => ['a type'],
      "language_label_tesim" => ['language'],
      "license_label_tesim" => ['license'],
      "rights_statement_label_tesim" => 'rights' }
  end

  let(:ability) { nil }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  subject { described_class.new(double, double) }

  it { is_expected.to delegate_method(:to_s).to(:solr_document) }
  it { is_expected.to delegate_method(:human_readable_type).to(:solr_document) }
  it { is_expected.to delegate_method(:date_created).to(:solr_document) }
  it { is_expected.to delegate_method(:creator_display).to(:solr_document) }
  it { is_expected.to delegate_method(:based_near_label).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement).to(:solr_document) }
  it { is_expected.to delegate_method(:depositor).to(:solr_document) }
  it { is_expected.to delegate_method(:resource_type).to(:solr_document) }
  it { is_expected.to delegate_method(:keyword).to(:solr_document) }

  it { is_expected.to delegate_method(:abstract).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:deposit_record).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:digital_collection).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:medium).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:language_label).to(:solr_document) }
  it { is_expected.to delegate_method(:license_label).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement_label).to(:solr_document) }

  describe "#model_name" do
    subject { presenter.model_name }

    it { is_expected.to be_kind_of ActiveModel::Name }
  end

  describe "#attribute_to_html" do
    let(:renderer) { double('renderer') }

    context 'with an existing field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:title, ['foo'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:title)
      end
    end

    context "with a custom abstract field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:abstract, ['an abstract'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:abstract)
      end
    end

    context "with a custom creator_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:creator_display, ['a creator'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:creator_display)
      end
    end

    context "with a custom date issued field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:date_issued, '2017-01-22', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
      end
    end

    context "with a custom deposit_record field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:deposit_record, 'a deposit record', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:deposit_record)
      end
    end

    context "with a custom doi field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:doi, '12345', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:doi)
      end
    end

    context "with a custom extent field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:extent, ['1999'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:extent)
      end
    end

    context "with a custom dcmi_type field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:dcmi_type, ['science fiction'], {}).and_return(renderer)
      end
      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:dcmi_type)
      end
    end

    context "with a custom digital collection field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:digital_collection, ['my collection'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:digital_collection)
      end
    end

    context "with a custom medium field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:medium, ['a medium'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:medium)
      end
    end

    context "with a custom note field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:note, ['a note'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:note)
      end
    end

    context "with a custom language label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:language_label, ['language'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:language_label)
      end
    end

    context "with a custom license label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:license_label, ['license'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:license_label)
      end
    end

    context "with a custom rights statement label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new)
          .with(:rights_statement_label, 'rights', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_statement_label)
      end
    end

    context "with a field that doesn't exist" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:something, 'foo', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).not_to receive(:render)
      end
    end
  end
end
