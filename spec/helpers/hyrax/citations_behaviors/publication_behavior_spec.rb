# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/helpers/hyrax/citations_behaviors/publication_behavior_override.rb')

RSpec.describe Hyrax::CitationsBehaviors::PublicationBehavior, type: :helper do
  describe '#setup_pub_date' do
    context 'with a publication date' do
      let(:work_with_date_issued) {
        Article.new(title: ['new article title'],
                    date_issued: '2019-10-11',
                    abstract: ['Test Abstract'],
                    creators_attributes: { '0' => { name: 'Test, Person',
                                                    affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                    index: 1 } })
      }

      it 'returns a formatted date from date issued' do
        expect(helper.setup_pub_date(work_with_date_issued)).to eq '2019'
      end
    end

    context 'with multiple publication dates' do
      let(:work_with_multiple_date_issued) {
        General.new(title: ['new article title'], date_issued: ['2011-01-01', '2012-04-12'])
      }

      it 'returns a formatted date for multiple date issued' do
        expect(helper.setup_pub_date(work_with_multiple_date_issued)).to eq '2011'
      end
    end

    context 'without a publication date' do
      let(:work_without_date_issued) {
        General.new(title: ['new article title'])
      }

      it 'does not return a formatted date from date issued if one is not present' do
        expect(helper.setup_pub_date(work_without_date_issued)).to eq nil
      end
    end

    context 'with an invalide publication date' do
      let(:work_with_bad_date_issued) {
        Article.new(title: ['new article title'],
                    date_issued: 'bad date',
                    abstract: ['Test Abstract'],
                    creators_attributes: { '0' => { name: 'Test, Person',
                                                    affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                    index: 1 } })
      }

      it 'does not return a formatted date for invalid dates' do
        expect(helper.setup_pub_date(work_with_bad_date_issued)).to eq nil
      end
    end
  end

  describe '#setup_pub_place' do
    let(:request) { double(host: 'example.org') }
    let(:user_key) { 'a_user_key' }
    let(:ability) { nil }

    context 'with a publication location' do
      let(:attributes) do
        { 'id' => '888888',
          'title_tesim' => ['foo'],
          'human_readable_type_tesim' => ['Article'],
          'has_model_ssim' => ['Article'],
          'depositor_tesim' => user_key,
          'abstract_tesim' => ['an abstract'],
          'access_right_tesim' => ['public'],
          'creator_display_tesim' => ['a creator'],
          'date_created_tesim' => '2017-01-22',
          'date_issued_tesim' => '2017-01-22',
          'place_of_publication_tesim' => ['durham']
        }
      end
      let(:solr_document) { SolrDocument.new(attributes) }
      let(:presenter) { Hyrax::ArticlePresenter.new(solr_document, ability, request) }

      it 'returns place of publication' do
        expect(helper.setup_pub_place(presenter)).to eq 'durham'
      end
    end

    context 'without a publication location' do
      let(:attributes_no_pub) do
        { 'id' => '888888',
          'title_tesim' => ['foo'],
          'human_readable_type_tesim' => ['Article'],
          'has_model_ssim' => ['Article'],
          'depositor_tesim' => user_key,
          'abstract_tesim' => ['an abstract'],
          'access_right_tesim' => ['public'],
          'creator_display_tesim' => ['a creator'],
          'date_created_tesim' => '2017-01-22',
          'date_issued_tesim' => '2017-01-22'
        }
      end
      let(:solr_document_no_pub) { SolrDocument.new(attributes_no_pub) }
      let(:presenter_no_pub) { Hyrax::ArticlePresenter.new(solr_document_no_pub, ability, request) }

      it 'returns nil if place of publication is absent' do
        expect(helper.setup_pub_place(presenter_no_pub)).to eq nil
      end
    end
  end

  describe '#setup_pub_info' do
    context 'with a publication location' do
      let(:work) {
        General.new(title: ['new article title'], place_of_publication: ['Chapel Hill, NC'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work)).to eq 'Chapel Hill, NC'
      end
    end

    context 'with a publication location and publisher' do
      let(:work) {
        General.new(title: ['new article title'], place_of_publication: ['Chapel Hill, NC'], publisher: ['UNC Press'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work)).to eq 'Chapel Hill, NC: UNC Press'
      end
    end

    context 'with a publisher' do
      let(:work) {
        General.new(title: ['new article title'], publisher: ['UNC Press'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work)).to eq 'UNC Press'
      end
    end

    context 'with publisher and publication date' do
      let(:work) {
        General.new(title: ['new article title'], publisher: ['UNC Press'], date_issued: ['2012-01-01'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work, true)).to eq 'UNC Press, 2012'
      end
    end

    context 'publication date' do
      let(:work) {
        General.new(title: ['new article title'], date_issued: ['2012-01-01'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work, true)).to eq '2012'
      end
    end

    context 'with location and date' do
      let(:work) {
        General.new(title: ['new article title'], place_of_publication: ['Chapel Hill, NC'], date_issued: ['2012-01-01'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work, true)).to eq 'Chapel Hill, NC, 2012'
      end
    end

    context 'with publisher, location and date' do
      let(:work) {
        General.new(title: ['new article title'], publisher: ['UNC Press'], place_of_publication: ['Chapel Hill, NC'], date_issued: ['2012-01-01'])
      }

      it 'returns publication info' do
        expect(helper.setup_pub_info(work, true)).to eq 'Chapel Hill, NC: UNC Press, 2012'
      end
    end

    context 'with no publication info' do
      let(:work) {
        General.new(title: ['new article title'])
      }

      it 'returns nil' do
        expect(helper.setup_pub_info(work)).to eq nil
      end
    end
  end

  describe '#journal_citation?' do
    it 'returns true when journal metadata is present' do
      work = Article.new(title: ['new article title'], journal_title: 'Journal of Testing')

      expect(helper.journal_citation?(work)).to be true
    end

    it 'returns false when journal metadata is absent' do
      work = General.new(title: ['new article title'])

      expect(helper.journal_citation?(work)).to be false
    end
  end

  describe '#setup_page_range' do
    it 'formats page ranges without style-specific prefixes' do
      work = Article.new(title: ['new article title'], page_start: '10', page_end: '18')

      expect(helper.setup_page_range(work)).to eq '10-18'
    end

    it 'formats a single page article correctly' do
      work = Article.new(title: ['new article title'], page_start: '10')

      expect(helper.setup_page_range(work)).to eq '10'
    end
  end

  describe '#setup_mla_page_range' do
    it 'formats mla page ranges with pp. and p. prefixes' do
      range_work = Article.new(title: ['new article title'], page_start: '10', page_end: '18')
      single_page_work = Article.new(title: ['new article title'], page_start: '10')

      expect(helper.setup_mla_page_range(range_work)).to eq 'pp. 10-18'
      expect(helper.setup_mla_page_range(single_page_work)).to eq 'p. 10'
    end
  end

  describe '#setup_journal_metadata' do
    let(:work) do
      Article.new(title: ['new article title'],
                  date_issued: '2019-10-11',
                  journal_title: 'Journal of Testing',
                  journal_volume: '12',
                  journal_issue: '3',
                  page_start: '10',
                  page_end: '18')
    end

    it 'returns style-neutral journal metadata' do
      expect(helper.setup_journal_metadata(work)).to eq(
        {
          journal_title: 'Journal of Testing',
          journal_volume: '12',
          journal_issue: '3',
          pub_date: '2019',
          page_range: '10-18'
        }
      )
    end
  end

  describe '#setup_doi' do
    it 'returns a doi value when present' do
      work = Article.new(title: ['new article title'], doi: 'doi.org/test-doi')

      expect(helper.setup_doi(work)).to eq 'doi.org/test-doi'
    end
  end
end
