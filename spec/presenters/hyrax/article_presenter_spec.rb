# Generated via
#  `rails generate hyrax:work Article`
require 'rails_helper'

RSpec.describe Hyrax::ArticlePresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { 'id' => '888888',
      'title_tesim' => ['foo'],
      'human_readable_type_tesim' => ['Article'],
      'has_model_ssim' => ['Article'],
      'depositor_tesim' => user_key,
      'abstract_tesim' => ['an abstract'],
      'access_tesim' => 'public',
      'alternative_title_tesim' => ['my other title'],
      'bibliographic_citation_tesim' => ['a citation'],
      'creator_display_tesim' => ['a creator'],
      'copyright_date_tesim' => '2017',
      'date_created_tesim' => '2017-01-22',
      'date_issued_tesim' => '2017-01-22',
      'date_other_tesim' => ['2017-01-22'],
      'dcmi_type_tesim' => ['science fiction'],
      'digital_collection_tesim' => ['my collection'],
      'deposit_record_tesim' => 'a deposit record',
      'doi_tesim' => '12345',
      'edition_tesim' => 'new edition',
      'extent_tesim' => ['1993'],
      'funder_tesim' => ['dean'],
      'based_near_tesim' => ['California'],
      'issn_tesim' => ['12345'],
      'journal_issue_tesim' => '27',
      'journal_title_tesim' => 'Journal Title',
      'journal_volume_tesim' => '4',
      'note_tesim' => ['a note'],
      'page_end_tesim' => '11',
      'page_start_tesim' => '8',
      'peer_review_status_tesim' => 'in review',
      'place_of_publication_tesim' => ['durham'],
      'rights_holder_tesim' => ['rights holder'],
      'translator_display_tesim' => ['dean'],
      'use_tesim' => ['a use'],
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
  it { is_expected.to delegate_method(:access).to(:solr_document) }
  it { is_expected.to delegate_method(:alternative_title).to(:solr_document) }
  it { is_expected.to delegate_method(:bibliographic_citation).to(:solr_document) }
  it { is_expected.to delegate_method(:copyright_date).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:date_other).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:deposit_record).to(:solr_document) }
  it { is_expected.to delegate_method(:digital_collection).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:edition).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:funder).to(:solr_document) }
  it { is_expected.to delegate_method(:issn).to(:solr_document) }
  it { is_expected.to delegate_method(:journal_issue).to(:solr_document) }
  it { is_expected.to delegate_method(:journal_title).to(:solr_document) }
  it { is_expected.to delegate_method(:journal_volume).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:page_end).to(:solr_document) }
  it { is_expected.to delegate_method(:page_start).to(:solr_document) }
  it { is_expected.to delegate_method(:peer_review_status).to(:solr_document) }
  it { is_expected.to delegate_method(:place_of_publication).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_holder).to(:solr_document) }
  it { is_expected.to delegate_method(:translator_display).to(:solr_document) }
  it { is_expected.to delegate_method(:use).to(:solr_document) }
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

    context 'with a custom access field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:access, 'public', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:access)
      end
    end

    context 'with a custom alternative title field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:alternative_title, ['my other title'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:alternative_title)
      end
    end

    context 'with a custom bibliographic_citation field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:bibliographic_citation, ['a citation'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:bibliographic_citation)
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

    context 'with a custom copyright date field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:copyright_date, '2017', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:copyright_date)
      end
    end

    context 'with a custom date issued field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, '2017-01-22', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
      end
    end

    context 'with a custom date other field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_other, ['2017-01-22'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_other)
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

    context 'with a custom digital collection field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:digital_collection, ['my collection'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:digital_collection)
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

    context 'with a custom edition field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:edition, 'new edition', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:edition)
      end
    end

    context 'with a custom extent field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:extent, ['1993'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:extent)
      end
    end

    context 'with a custom funder field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:funder, ['dean'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:funder)
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

    context 'with a custom issn field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:issn, ['12345'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:issn)
      end
    end

    context 'with a custom journal issue field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:journal_issue, '27', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:journal_issue)
      end
    end

    context 'with a custom journal title field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:journal_title, 'Journal Title', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:journal_title)
      end
    end

    context 'with a custom journal volume field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:journal_volume, '4', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:journal_volume)
      end
    end

    context 'with a custom note field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:note, ['a note'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:note)
      end
    end

    context 'with a custom page end field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:page_end, '11', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:page_end)
      end
    end

    context 'with a custom page start field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:page_start, '8', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:page_start)
      end
    end

    context 'with a custom peer review status field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:peer_review_status, 'in review', {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:peer_review_status)
      end
    end

    context 'with a custom place of publication field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:place_of_publication, ['durham'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:place_of_publication)
      end
    end

    context 'with a custom rights holder field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_holder, ['rights holder'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_holder)
      end
    end

    context 'with a custom translator_display field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:translator_display, ['dean'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:translator_display)
      end
    end

    context 'with a custom use field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:use, ['a use'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:use)
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
end
