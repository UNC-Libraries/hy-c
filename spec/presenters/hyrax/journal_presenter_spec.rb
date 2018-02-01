# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Hyrax::JournalPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'unc.lib.edu') }
  let(:user_key) { 'user_id' }

  let(:attributes) do
    { "id" => '3333',
      "title_tesim" => ['cdr'],
      "human_readable_type_tesim" => ["Journal"],
      "has_model_ssim" => ["Journal"],
      "date_created_tesim" => ['an unformatted date'],
      "depositor_tesim" => user_key,
      "abstract_tesim" => ['an abstract'],
      "alternate_title_tesim" => ['a different title'],
      "conference_name_tesim" => ['Code4Lib'],
      "date_issued_tesim" => ['2018-01-08'],
      "discipline_tesim" => ['a discipline'],
      "extent_tesim" => ['1993'],
      "format_tesim" => ['a format'],
      "genre_tesim" => ['a genre'],
      "geographic_subject_tesim" => ['California'],
      "issn_tesim" => ['12345'],
      "note_tesim" => ['a note'],
      "place_of_publication_tesim" => ['California'],
      "record_content_source_tesim" => ['a source'],
      "resource_type_tesim" => ['a type'],
      "reviewer_tesim" => ['a reviewer'],
      "table_of_contents_tesim" => ['table of contents']
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
  it { is_expected.to delegate_method(:alternate_title).to(:solr_document) }
  it { is_expected.to delegate_method(:conference_name).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:issn).to(:solr_document) }
  it { is_expected.to delegate_method(:genre).to(:solr_document) }
  it { is_expected.to delegate_method(:geographic_subject).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:place_of_publication).to(:solr_document) }
  it { is_expected.to delegate_method(:table_of_contents).to(:solr_document) }

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

    context "with a custom alternate title field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:alternate_title, ['a different title'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:alternate_title)
      end
    end

    context "with a custom conference name field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:conference_name, ['Code4Lib'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:conference_name)
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

    context "with a custom genre field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:genre, ['a genre'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:genre)
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

    context "with a custom issn field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:issn, ['12345'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:issn)
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
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:place_of_publication, ['California'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:place_of_publication)
      end
    end

    context "with a custom table of contents field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:table_of_contents, ['table of contents'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:table_of_contents)
      end
    end
  end
end
