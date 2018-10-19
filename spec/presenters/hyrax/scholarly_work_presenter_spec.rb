# Generated via
#  `rails generate hyrax:work ScholarlyWork`
require 'rails_helper'

RSpec.describe Hyrax::ScholarlyWorkPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { "id" => '888888',
      "title_tesim" => ['foo'],
      "human_readable_type_tesim" => ["Article"],
      "has_model_ssim" => ["Article"],
      "date_created_tesim" => ['an unformatted date'],
      "depositor_tesim" => user_key,
      "abstract_tesim" => ['an abstract'],
      "advisor_tesim" => ['an advisor'],
      "conference_name_tesim" => ['a conference'],
      "date_issued_tesim" => ['a date'],
      "dcmi_type_tesim" => ['science fiction'],
      "deposit_record_tesim" => 'a deposit record',
      "doi_tesim" => '12345',
      "geographic_subject_tesim" => ['a geographic subject'],
      "orcid_tesim" => ['an orcid'],
      "other_affiliation_tesim" => ['another affiliation'],
      "language_label_tesim" => ['language'],
      "license_label_tesim" => ['license'],
      "rights_statement_label_tesim" => ['rights']
    }
  end
  let(:ability) { nil }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  subject { described_class.new(double, double) }

  it { is_expected.to delegate_method(:to_s).to(:solr_document) }
  it { is_expected.to delegate_method(:human_readable_type).to(:solr_document) }
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
  it { is_expected.to delegate_method(:advisor).to(:solr_document) }
  it { is_expected.to delegate_method(:conference_name).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:deposit_record).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:geographic_subject).to(:solr_document) }
  it { is_expected.to delegate_method(:orcid).to(:solr_document) }
  it { is_expected.to delegate_method(:other_affiliation).to(:solr_document) }
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
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:abstract, ['an abstract'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:abstract)
      end
    end

    context "with a custom advisor field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:advisor, ['an advisor'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:advisor)
      end
    end

    context "with a custom conference_name field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:conference_name, ['a conference'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:conference_name)
      end
    end

    context "with a custom date_issued field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, ['a date'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
      end
    end

    context "with a custom deposit_record field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:deposit_record, 'a deposit record', {}).and_return(renderer)
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

    context "with a custom dcmi_type field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:dcmi_type, ['science fiction'], {}).and_return(renderer)
      end
      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:dcmi_type)
      end
    end

    context "with a custom geographic_subject field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:geographic_subject, ['a geographic subject'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:geographic_subject)
      end
    end

    context "with a custom orcid field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:orcid, ['an orcid'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:orcid)
      end
    end

    context "with a custom other_affiliation field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:other_affiliation, ['another affiliation'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:other_affiliation)
      end
    end

    context "with a custom language label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:language_label, ['language'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:language_label)
      end
    end

    context "with a custom license label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:license_label, ['license'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:license_label)
      end
    end

    context "with a custom rights statement label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_statement_label, ['rights'], {}).and_return(renderer)
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
