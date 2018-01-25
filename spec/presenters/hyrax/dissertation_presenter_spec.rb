# Generated via
#  `rails generate hyrax:work Dissertation`
require 'rails_helper'

RSpec.describe Hyrax::DissertationPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { "id" => '888888',
      "title_tesim" => ['foo'],
      "human_readable_type_tesim" => ["Dissertation"],
      "has_model_ssim" => ["Dissertation"],
      "date_created_tesim" => ['an unformatted date'],
      "depositor_tesim" => user_key,
      "abstract_tesim" => ['an abstract'],
      "academic_concentration_tesim" => ['a concentration'],
      "affiliation_tesim" => ['a department'],
      "access_tesim" => ['an access state'],
      "advisor_tesim" => ['an advisor'],
      "date_issued_tesim" => ['2018-01-08'],
      "degree_tesim" => ['a degree'],
      "degree_granting_institution_tesim" => ['an institution'],
      "discipline_tesim" => ['a discipline'],
      "doi_tesim" => ['a doi'],
      "format_tesim" => ['a format'],
      "genre_tesim" => ['a genre'],
      "graduation_year_tesim" => ['a year'],
      "note_tesim" => ['a note'],
      "place_of_publication_tesim" => ['a place'],
      "record_content_source_tesim" => ['a source'],
      "resource_type_tesim" => ['a type'],
      "reviewer_tesim" => ['a reviewer']
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
  it { is_expected.to delegate_method(:academic_concentration).to(:solr_document) }
  it { is_expected.to delegate_method(:affiliation).to(:solr_document) }
  it { is_expected.to delegate_method(:access).to(:solr_document) }
  it { is_expected.to delegate_method(:advisor).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:degree).to(:solr_document) }
  it { is_expected.to delegate_method(:degree_granting_institution).to(:solr_document) }
  it { is_expected.to delegate_method(:discipline).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:format).to(:solr_document) }
  it { is_expected.to delegate_method(:genre).to(:solr_document) }
  it { is_expected.to delegate_method(:graduation_year).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:place_of_publication).to(:solr_document) }
  it { is_expected.to delegate_method(:record_content_source).to(:solr_document) }
  it { is_expected.to delegate_method(:reviewer).to(:solr_document) }

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

    context "with a custom academic_concentration field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:academic_concentration, ['a concentration'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:academic_concentration)
      end
    end

    context "with a custom academic_department field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:affiliation, ['a department'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:affiliation)
      end
    end

    context "with a custom access field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:access, ['an access state'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:access)
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

    context "with a custom date_issued field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, ['2018-01-08'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
      end
    end

    context "with a custom degree field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:degree, ['a degree'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:degree)
      end
    end

    context "with a custom degree_granting_institution field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:degree_granting_institution, ['an institution'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:degree_granting_institution)
      end
    end

    context "with a custom discipline field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:discipline, ['a discipline'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:discipline)
      end
    end

    context "with a custom doi field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:doi, ['a doi'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:doi)
      end
    end

    context "with a custom format field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:format, ['a format'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:format)
      end
    end

    context "with a custom genre field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:genre, ['a genre'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:genre)
      end
    end

    context "with a custom graduation_year field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:graduation_year, ['a year'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:graduation_year)
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

    context "with a custom place_of_publication field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:place_of_publication, ['a place'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:place_of_publication)
      end
    end

    context "with a custom record_content_source field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:record_content_source, ['a source'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:record_content_source)
      end
    end

    context "with a custom resource_type field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:resource_type, ['a type'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:resource_type)
      end
    end

    context "with a custom reviewer field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:reviewer, ['a reviewer'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:reviewer)
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
