# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/presenters/hyrax/work_show_presenter_override.rb')

RSpec.describe Hyrax::WorkShowPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org', base_url: 'http://example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { 'id' => '888888',
      'title_tesim' => ['foo', 'bar'],
      'human_readable_type_tesim' => ['Article'],
      'has_model_ssim' => ['Article'],
      'date_created_tesim' => ['an unformatted date'],
      'depositor_tesim' => user_key }
  end
  let(:ability) { double Ability }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  subject { described_class.new(double, double) }

  it { is_expected.to delegate_method(:doi).to(:solr_document) }

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

  describe '#manifest_metadata' do
    context 'work with a doi' do
      let(:work) { Article.new(title: ['Test title']) }
      let(:solr_document) { SolrDocument.new(work.to_solr) }

      before do
        work.doi = 'http://doi.org'
      end

      it 'returns an array of metadata values' do
        expect(presenter.manifest_metadata)
          .to contain_exactly({ 'label' => 'Title', 'value' => ['Test title'] },
                              { 'label' => 'DOI', 'value' => ['http://doi.org'] })
      end
    end

    context 'with a person object' do
      let(:work) { Article.new(title: ['Test title 2']) }
      let(:solr_document) { SolrDocument.new(work.to_solr) }

      before do
        work.creators_attributes = { '0' => { name: 'Test, Person',
                                              affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                              index: 1 } }
      end

      it 'returns an array of metadata values' do
        expect(presenter.manifest_metadata)
          .to contain_exactly({ 'label' => 'Title', 'value' => ['Test title 2'] },
                              { 'label' => 'Creator', 'value' => ['Test, Person'] })
      end
    end
  end
end
