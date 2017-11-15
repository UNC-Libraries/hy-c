# Generated via
#  `rails generate hyrax:work OpenAccess`
require 'rails_helper'

RSpec.describe Hyrax::OpenAccessPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { "id" => '888888',
      "title_tesim" => ['foo'],
      "human_readable_type_tesim" => ["OpenAccess"],
      "has_model_ssim" => ["OpenAccess"],
      "date_created_tesim" => ['an unformatted date'],
      "depositor_tesim" => user_key,
      "academic_department_tesim" => ['a department'],
      "additional_funding_tesim" => ['other funding'],
      "author_status_tesim" => ['faculty'],
      "coauthor_tesim" => ['a coauthor'],
      "granting_agency_tesim" => ['some funding'],
      "issue_tesim" => ['first issue'],
      "link_to_publisher_version_tesim" => ['a link'],
      "orcid_tesim" => ['an orcid id'],
      "publication_tesim" => ['a publication'],
      "publication_date_tesim" => ['a date'],
      "publication_version_tesim" => ['another version']
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
  it { is_expected.to delegate_method(:academic_department).to(:solr_document) }
  it { is_expected.to delegate_method(:additional_funding).to(:solr_document) }
  it { is_expected.to delegate_method(:author_status).to(:solr_document) }
  it { is_expected.to delegate_method(:coauthor).to(:solr_document) }
  it { is_expected.to delegate_method(:granting_agency).to(:solr_document) }
  it { is_expected.to delegate_method(:issue).to(:solr_document) }
  it { is_expected.to delegate_method(:link_to_publisher_version).to(:solr_document) }
  it { is_expected.to delegate_method(:orcid).to(:solr_document) }
  it { is_expected.to delegate_method(:publication).to(:solr_document) }
  it { is_expected.to delegate_method(:publication_date).to(:solr_document) }
  it { is_expected.to delegate_method(:publication_version).to(:solr_document) }

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

    context "with a custom faculty academic_department field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:academic_department, ['a department'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:academic_department)
      end
    end

    context "with a custom additional_funding field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:additional_funding, ['other funding'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:additional_funding)
      end
    end

    context "with a custom author_status field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:author_status, ['faculty'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:author_status)
      end
    end

    context "with a custom coauthor field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:coauthor, ['a coauthor'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:coauthor)
      end
    end

    context "with a custom granting_agency field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:granting_agency, ['some funding'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:granting_agency)
      end
    end

    context "with a custom issue field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:issue, ['first issue'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:issue)
      end
    end

    context "with a custom link_to_publisher_version field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:link_to_publisher_version, ['a link'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:link_to_publisher_version)
      end
    end

    context "with a custom orcid field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:orcid, ['an orcid id'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:orcid)
      end
    end

    context "with a custom publication field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:publication, ['a publication'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:publication)
      end
    end

    context "with a custom publication_date field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:publication_date, ['a date'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:publication_date)
      end
    end

    context "with a custom publication_version field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:publication_version, ['another version'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:publication_version)
      end
    end

    context "with a field that doesn't exist" do
      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with('Hyrax::OpenAccessPresenter attempted to render restrictions, but no method exists with that name.')
        presenter.attribute_to_html(:restrictions)
      end
    end
  end
end
