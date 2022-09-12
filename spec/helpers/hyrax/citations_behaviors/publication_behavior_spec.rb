# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/helpers/hyrax/citations_behaviors/publication_behavior_override.rb')

RSpec.describe Hyrax::CitationsBehaviors::PublicationBehavior, type: :helper do
  context 'with a publication date' do
    let(:work_with_date_issued) {
      Article.new(title: ['new article title'],
                  date_issued: '2019-10-11',
                  abstract: ['Test Abstract'],
                  creators_attributes: { '0' => { name: 'Test, Person',
                                                  affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                  index: 1 } })
    }

    let(:work_with_multiple_date_issued) {
      General.new(title: ['new article title'], date_issued: ['2011-01-01', '2012-04-12'])
    }

    let(:work_without_date_issued) {
      General.new(title: ['new article title'])
    }

    let(:work_with_bad_date_issued) {
      Article.new(title: ['new article title'],
                  date_issued: 'bad date',
                  abstract: ['Test Abstract'],
                  creators_attributes: { '0' => { name: 'Test, Person',
                                                  affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                  index: 1 } })
    }

    it 'returns a formatted date from date issued' do
      expect(helper.setup_pub_date(work_with_date_issued)).to eq '2019'
    end

    it 'returns a formatted date for multiple date issued' do
      expect(helper.setup_pub_date(work_with_multiple_date_issued)).to eq '2011'
    end

    it 'does not return a formatted date from date issued if one is not present' do
      expect(helper.setup_pub_date(work_without_date_issued)).to eq nil
    end

    it 'does not return a formatted date for invalid dates' do
      expect(helper.setup_pub_date(work_with_bad_date_issued)).to eq nil
    end

  end

  context 'with a publication place' do
    let(:solr_document) { SolrDocument.new(attributes) }
    let(:solr_document_no_pub) { SolrDocument.new(attributes_no_pub) }
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
        'creator_display_tesim' => ['a creator'],
        'date_created_tesim' => '2017-01-22',
        'date_issued_tesim' => '2017-01-22',
        'place_of_publication_tesim' => ['durham']
      }
    end

    let(:attributes_no_pub) do
      { 'id' => '888888',
        'title_tesim' => ['foo'],
        'human_readable_type_tesim' => ['Article'],
        'has_model_ssim' => ['Article'],
        'depositor_tesim' => user_key,
        'abstract_tesim' => ['an abstract'],
        'access_tesim' => 'public',
        'creator_display_tesim' => ['a creator'],
        'date_created_tesim' => '2017-01-22',
        'date_issued_tesim' => '2017-01-22'
      }
    end

    let(:ability) { nil }
    let(:presenter) { Hyrax::ArticlePresenter.new(solr_document, ability, request) }

    let(:presenter_no_pub) { Hyrax::ArticlePresenter.new(solr_document_no_pub, ability, request) }

    it 'returns place of publication, if present' do
      expect(helper.setup_pub_place(presenter)).to eq 'durham'
    end

    it 'returns nil if place of publication is absent' do
      expect(helper.setup_pub_place(presenter_no_pub)).to eq nil
    end
  end
end
