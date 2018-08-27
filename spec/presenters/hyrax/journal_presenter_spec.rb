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
      "alternative_title_tesim" => ['a different title'],
      "date_issued_tesim" => ['2018-01-08'],
      "dcmi_type_tesim" => ['science fiction'],
      "deposit_record_tesim" => 'a deposit record',
      "doi_tesim" => '12345',
      "extent_tesim" => ['1993'],
      "geographic_subject_tesim" => ['California'],
      "isbn_tesim" => ['123456'],
      "issn_tesim" => ['12345'],
      "note_tesim" => ['a note'],
      "orcid_tesim" => ['an orcid'],
      "place_of_publication_tesim" => ['California'],
      "resource_type_tesim" => ['a type'],
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
  it { is_expected.to delegate_method(:alternative_title).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:deposit_record).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:geographic_subject).to(:solr_document) }
  it { is_expected.to delegate_method(:isbn).to(:solr_document) }
  it { is_expected.to delegate_method(:issn).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:orcid).to(:solr_document) }
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

    context "with a custom alternative title field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:alternative_title, ['a different title'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:alternative_title)
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

    context "with a custom extent field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:extent, ['1993'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:extent)
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

    context "with a custom isbn field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:isbn, ['123456'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:isbn)
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

    context "with a custom orcid field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:orcid, ['an orcid'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:orcid)
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
