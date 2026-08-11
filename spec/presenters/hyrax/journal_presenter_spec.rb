# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Hyrax::JournalPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'unc.lib.edu') }
  let(:user_key) { 'user_id' }

  let(:attributes) do
    { 'id' => '3333',
      'title_tesim' => ['cdr'],
      'human_readable_type_tesim' => ['Journal'],
      'has_model_ssim' => ['Journal'],
      'creator_display_tesim' => ['a creator'],
      'date_created_tesim' => ['an unformatted date'],
      'depositor_tesim' => user_key,
      'abstract_tesim' => ['an abstract'],
      'alternative_title_tesim' => ['a different title'],
      'date_issued_tesim' => ['2018-01-08'],
      'dcmi_type_tesim' => ['science fiction'],
      'deposit_record_tesim' => 'a deposit record',
      'digital_collection_tesim' => ['my collection'],
      'doi_tesim' => '12345',
      'edition_tesim' => 'First Edition',
      'embargo_history_ssim' => ['Embargo created 2017-01-22'],
      'extent_tesim' => ['1993'],
      'based_near_tesim' => ['California'],
      'isbn_tesim' => ['123456'],
      'issn_tesim' => ['12345'],
      'note_tesim' => ['a note'],
      'place_of_publication_tesim' => ['California'],
      'resource_type_tesim' => ['a type'],
      'series_tesim' => ['series1'],
      'language_label_tesim' => ['language'],
      'license_label_tesim' => ['license'],
      'rights_statement_label_tesim' => 'rights',
      'related_url_tesim' => 'a url'
    }
  end

  let(:ability) { nil }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  describe 'solr document field access' do
    it 'returns the stored value for every attribute field', :aggregate_failures do
      attributes.each do |solr_key, expected_value|
        next if solr_key == 'id' || solr_key == 'has_model_ssim'
        field_name = solr_key.sub(/_[^_]+\z/, '')
        expect(Array(presenter.send(field_name))).to eq(Array(expected_value)),
          "expected presenter.#{field_name} (from #{solr_key}) to return #{expected_value.inspect}"
      end
    end
  end

  describe '#model_name' do
    subject { presenter.model_name }

    it { is_expected.to be_kind_of ActiveModel::Name }
    it { expect(subject.human).to eq 'Journal' }
  end

  describe '#embargo_history' do
    it 'returns embargo history from the solr document' do
      expect(presenter.embargo_history).to eq(['Embargo created 2017-01-22'])
    end

    context 'when embargo history is not present' do
      let(:attributes) { super().except('embargo_history_ssim') }

      it 'returns an empty array' do
        expect(presenter.embargo_history).to eq([])
      end
    end
  end

  describe '#attribute_to_html' do
    let(:renderer) { double('renderer') }

    context 'with a custom abstract field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:abstract, ['an abstract'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:abstract)
      end
    end

    context 'with a custom alternative title field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:alternative_title, ['a different title'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:alternative_title)
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
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, ['2018-01-08'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
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
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:edition, 'First Edition', {}).and_return(renderer)
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

    context 'with a custom dcmi_type field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:dcmi_type, ['science fiction'], {}).and_return(renderer)
      end
      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:dcmi_type)
      end
    end

    context 'with a custom isbn field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:isbn, ['123456'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:isbn)
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

    context 'with a custom note field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:note, ['a note'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:note)
      end
    end

    context 'with a custom place_of_publication field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:place_of_publication, ['California'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:place_of_publication)
      end
    end

    context 'with a custom series field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:series, ['series1'], {}).and_return(renderer)
      end

      it 'calls the AttributeRenderer' do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:series)
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
