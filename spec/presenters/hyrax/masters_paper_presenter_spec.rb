# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

RSpec.describe Hyrax::MastersPaperPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { "id" => '888888',
      "title_tesim" => ['foo'],
      "human_readable_type_tesim" => ["MastersPaper"],
      "has_model_ssim" => ["MastersPaper"],
      "date_created_tesim" => ['an unformatted date'],
      "depositor_tesim" => user_key,
      "faculty_advisor_name_tesim" => ['someone'],
      "date_published_tesim" => ['10-08-2017'],
      "author_degree_granted_tesim" => ['MSIS'],
      "author_graduation_date_tesim" => ['10-08-2017'],
      "author_academic_concentration_tesim" => ['Biology'],
      "institution_tesim" => ['an institution'],
      "citation_tesim" => ['a citation']
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
  it { is_expected.to delegate_method(:faculty_advisor_name).to(:solr_document) }
  it { is_expected.to delegate_method(:date_published).to(:solr_document) }
  it { is_expected.to delegate_method(:author_graduation_date).to(:solr_document) }
  it { is_expected.to delegate_method(:author_degree_granted).to(:solr_document) }


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

    context "with a custom faculty advisor name field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:faculty_advisor_name, ['someone'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:faculty_advisor_name)
      end
    end

    context "with a custom date_published field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_published, ['10-08-2017'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_published)
      end
    end

    context "with a custom author_graduation_date field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:author_graduation_date, ['10-08-2017'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:author_graduation_date)
      end
    end

    context "with a custom author_degree_granted field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:author_degree_granted, ['MSIS'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:author_degree_granted)
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
