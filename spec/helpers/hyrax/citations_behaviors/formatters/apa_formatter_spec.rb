require 'rails_helper'

RSpec.describe Hyrax::CitationsBehaviors::Formatters::ApaFormatter do
  subject(:formatter) { described_class.new(:no_context) }
  let(:article) { Article.new(title: ['new article title'],
                              creators_attributes: {'0' => {'name' => 'a depositor'}},
                              date_issued: '2019-10-11',
                              publisher: ['a publisher'],
                              place_of_publication: ['NC'],
                              doi: 'doi.org/some-doi')
  }  
  let(:presenter) { Hyrax::WorkShowPresenter.new(SolrDocument.new(article.to_solr), :no_ability) }

  describe '#format' do
    it 'returns a citation in apa format with a doi' do
      expect(formatter.format(presenter)).to eq '<span class="citation-author">Depositor, A.</span> (2019). <i class="citation-title">new article title.</i> NC: a publisher. doi.org/some-doi'
    end
  end

  describe '#format_authors' do
    let(:author_list) { ['Jane Doe', 'Henry Miller'] }

    it 'returns authors' do
      expect(formatter.format_authors(author_list)).to eq 'Doe, J., &amp; Miller, H.'
    end
  end

  describe '#format_date' do
    it 'returns a date formatted for citation' do
      expect(formatter.format_date(presenter.date_issued.first)).to eq '(October 11, 2019). '
    end
  end

  describe '#format_title' do
    it 'returns a title formatted for citation' do
      expect(formatter.format_title(presenter.title.first)).to eq '<i class="citation-title">new article title</i> '
    end
  end

  # behavior methods
  describe '#author_list' do
    it 'returns a list of authors' do
      expect(formatter.author_list(presenter)).to eq ['A Depositor']
    end
  end

  describe '#all_authors' do
    it 'returns list of authors' do
      expect(formatter.all_authors(presenter)).to eq ['A Depositor']
    end
  end

  describe '#given_name_first' do
    let(:author) { 'Doe, Jane' }

    it 'returns given name' do
      expect(formatter.given_name_first(author)).to eq 'Jane Doe'
    end
  end

  describe '#surname_first' do
    let(:author) { 'Jane Doe' }

    it 'returns given name' do
      expect(formatter.surname_first(author)).to eq 'Doe, Jane'
    end
  end

  describe '#abbreviate_name' do
    let(:author) { 'Jane Doe' }

    it 'returns given name' do
      expect(formatter.abbreviate_name(author)).to eq 'Doe, J.'
    end
  end

  describe '#setup_pub_date' do
    it 'returns publication date' do
      expect(formatter.setup_pub_date(presenter)).to eq '2019'
    end
  end

  describe '#setup_pub_place' do
    it 'returns a publication date' do
      expect(formatter.setup_pub_place(presenter)).to eq 'NC'
    end
  end

  describe '#setup_pub_publisher' do
    it 'returns a publication date' do
      expect(formatter.setup_pub_publisher(presenter)).to eq 'a publisher'
    end
  end

  describe '#setup_pub_info' do
    it 'returns a publication date' do
      expect(formatter.setup_pub_info(presenter)).to eq 'NC: a publisher'
    end
  end
end
