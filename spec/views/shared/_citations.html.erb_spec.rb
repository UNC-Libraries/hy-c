# frozen_string_literal: true
require 'rails_helper'
RSpec.describe 'shared/_citations.html.erb', type: :view do
  let(:depositor) { FactoryBot.create(:user) }
  let(:creator_display) { ['index:2||Bilbo Baggins', 'index:1||Baggins, Frodo'] }

  let(:ability) { double }

  describe 'google scholar' do
    context 'with journal article' do
      let(:work_solr_document) do
        SolrDocument.new(
          id: '999',
          has_model_ssim: ['Article'],
          human_readable_type_tesim: ['Article'],
          creator_display_tesim: creator_display,
          license_tesim: ['http://creativecommons.org/licenses/by/3.0/us/'],
          title_tesim: ['Sail the Seven Hycs'],
          date_issued_tesim: ['1970'],
          doi_tesim: ['http://dx.doi.org/10.1186/1753-6561-3-S7-S87'],
          journal_volume_tesim: ['55'],
          journal_issue_tesim: ['10'],
          page_start_tesim: ['99'],
          page_end_tesim: ['106'],
          keyword_tesim: ['bacon', 'sausage', 'eggs'],
          publisher_tesim: ['French Press'],
          description_tesim: ['Abstraction layer']
        )
      end

      let(:presenter) do
        Hyrax::ArticlePresenter.new(work_solr_document, ability)
      end

      before do
        allow(view).to receive(:polymorphic_url)
        assign(:presenter, presenter)
        render
      end

      let(:gs_rendered) { Nokogiri::HTML(view.content_for(:gscholar_meta)) }

      it 'appears in meta tags' do
        gscholar_meta_tags = gs_rendered.xpath("//meta[contains(@name, 'citation_')]")
        expect(gscholar_meta_tags.count).to eq(10)
      end

      it 'displays regular and journal meta data tags' do
        tag = gs_rendered.xpath("//meta[@name='description']")
        expect(tag.attribute('content').value).to eq('Abstraction layer')

        tag = gs_rendered.xpath("//meta[@name='citation_title']")
        expect(tag.attribute('content').value).to eq('Sail the Seven Hycs')

        tags = gs_rendered.xpath("//meta[@name='citation_author']")
        expect(tags.first.attribute('content').value).to eq('Baggins, Frodo')
        expect(tags.last.attribute('content').value).to eq('Bilbo Baggins')

        tag = gs_rendered.xpath("//meta[@name='citation_publication_date']")
        expect(tag.attribute('content').value).to eq('1970')

        tag = gs_rendered.xpath("//meta[@name='citation_pdf_url']")
        expect(tag).to be_blank

        tag = gs_rendered.xpath("//meta[@name='citation_keywords']")
        expect(tag.attribute('content').value).to eq('bacon; sausage; eggs')

        tag = gs_rendered.xpath("//meta[@name='citation_publisher']")
        expect(tag.attribute('content').value).to eq('French Press')
      end
    end

    context 'with multimedia (non-scholarly)' do
      let(:work_solr_document) do
        SolrDocument.new(
          id: '999',
          has_model_ssim: ['Multimed'],
          human_readable_type_tesim: ['Multimed'],
          creator_display_tesim: creator_display,
          title_tesim: ['Sail the Seven Hycs'],
          date_issued_tesim: ['1970'],
          keyword_tesim: ['bacon', 'sausage', 'eggs'],
          publisher_tesim: ['French Press'],
          description_tesim: ['Abstraction layer']
        )
      end

      let(:presenter) do
        Hyrax::MultimedPresenter.new(work_solr_document, ability)
      end

      before do
        allow(view).to receive(:polymorphic_url)
        assign(:presenter, presenter)
        render
      end

      let(:gs_rendered) { Nokogiri::HTML(view.content_for(:gscholar_meta)) }

      it 'has no citation meta tags' do
        gscholar_meta_tags = gs_rendered.xpath("//meta[contains(@name, 'citation_')]")
        expect(gscholar_meta_tags.count).to eq(0)
      end
    end
  end
end
