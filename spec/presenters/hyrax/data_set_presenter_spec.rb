# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'

RSpec.describe Hyrax::DataSetPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'unc.lib.edu') }
  let(:user_key) { 'user_id' }

  let(:attributes) do
    { "id" => '1971',
      "title_tesim" => ['cdr'],
      "human_readable_type_tesim" => ['DataSet'],
      "has_model_ssim" => ['DataSet'],
      "date_created_tesim" => ['an unformatted date'],
      "depositor_tesim" => user_key,
      "resource_type_tesim" => ['a type'],
      "abstract_tesim" => ['an abstract'],
      "affiliation_tesim" => ['SILS'],
      "copyright_date_tesim" => '2017-12-19',
      "date_issued_tesim" => '2018-01-08',
      "dcmi_type_tesim" => ['science fiction'],
      "deposit_record_tesim" => 'a deposit record',
      "doi_tesim" => '12345',
      "extent_tesim" => ['1993'],
      "funder_tesim" => ['unc'],
      "geographic_subject_tesim" => ['California'],
      "kind_of_data_tesim" => ['some data'],
      "last_modified_date_tesim" => '2018-01-29',
      "orcid_tesim" => ['an orcid'],
      "other_affiliation_tesim" => ['another affiliation'],
      "project_director_tesim" => ['ben'],
      "researcher_tesim" => ['jennifer'],
      "rights_holder_tesim" => ['julie'],
      "sponsor_tesim" => ['joe'],
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
  it { is_expected.to delegate_method(:depositor).to(:solr_document) }
  it { is_expected.to delegate_method(:identifier).to(:solr_document) }
  it { is_expected.to delegate_method(:resource_type).to(:solr_document) }
  it { is_expected.to delegate_method(:itemtype).to(:solr_document) }

  it { is_expected.to delegate_method(:abstract).to(:solr_document) }
  it { is_expected.to delegate_method(:affiliation).to(:solr_document) }
  it { is_expected.to delegate_method(:copyright_date).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:deposit_record).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:funder).to(:solr_document) }
  it { is_expected.to delegate_method(:geographic_subject).to(:solr_document) }
  it { is_expected.to delegate_method(:kind_of_data).to(:solr_document) }
  it { is_expected.to delegate_method(:last_modified_date).to(:solr_document) }
  it { is_expected.to delegate_method(:orcid).to(:solr_document) }
  it { is_expected.to delegate_method(:other_affiliation).to(:solr_document) }
  it { is_expected.to delegate_method(:project_director).to(:solr_document) }
  it { is_expected.to delegate_method(:researcher).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_holder).to(:solr_document) }
  it { is_expected.to delegate_method(:sponsor).to(:solr_document) }
  it { is_expected.to delegate_method(:language_label).to(:solr_document) }
  it { is_expected.to delegate_method(:license_label).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement_label).to(:solr_document) }

  describe "#model_name" do
    subject { presenter.model_name }

    it { is_expected.to be_kind_of ActiveModel::Name }
  end

  describe "#attribute_to_html" do
    let(:renderer) { double('renderer') }

    context "with a custom abstract field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:abstract, ['an abstract'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:abstract)
      end
    end

    context "with a custom affiliation field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:affiliation, ['SILS'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:affiliation)
      end
    end

    context "with a custom copyright date field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:copyright_date, '2017-12-19', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:copyright_date)
      end
    end

    context "with a custom date issued field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, '2018-01-08', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
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
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:extent, ['1993'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:extent)
      end
    end

    context "with a custom funder field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:funder, ['unc'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:funder)
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

    context "with a custom geographic subject field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:geographic_subject, ['California'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:geographic_subject)
      end
    end

    context "with a custom kind_of_data field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:kind_of_data, ['some data'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:kind_of_data)
      end
    end

    context "with a custom last date modified field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:last_modified_date, '2018-01-29', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:last_modified_date)
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

    context "with a custom project director field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:project_director, ['ben'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:project_director)
      end
    end

    context "with a custom researcher field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:researcher, ['jennifer'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:researcher)
      end
    end

    context "with a custom rights holder field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_holder, ['julie'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_holder)
      end
    end

    context "with a custom sponsor field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:sponsor, ['joe'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:sponsor)
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
