require 'rails_helper'

RSpec.describe HyraxHelper do
  describe '#language_links' do
    context 'with valid options' do
      let(:options) { {value: ['http://id.loc.gov/vocabulary/iso639-2/eng']} }

      it 'returns a link to a language search' do
        expect(helper.language_links(options)).to eq '<a href="/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng">English</a>'
      end
    end

    context 'with invalid options' do
      let(:invalid_options) { {value: ['invalid']} }

      it 'returns nil if language key is not found' do
        expect(helper.language_links(invalid_options)).to eq nil
      end
    end
  end

  describe '#language_links_facets' do
    context 'with valid options' do
      let(:options) { 'http://id.loc.gov/vocabulary/iso639-2/eng' }

      it 'returns a link to a language search' do
        expect(helper.language_links_facets(options)).to eq '<a href="/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng">English</a>'
      end
    end

    context 'with invalid options' do
      let(:invalid_options) { 'invalid' }

      it 'returns nil if language key is not found' do
        expect(helper.language_links_facets(invalid_options)).to eq invalid_options
      end
    end
  end

  describe '#redirect_lookup' do
    cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
    tempfile = Tempfile.new('redirect_uuids.csv', 'spec/fixtures/')
    let(:article) { Article.create(title: ['new article'], visibility: 'open') }

    before do
      ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
      File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
        f.puts 'uuid,new_path'
        f.puts "02fc897a-12b6-4b81-91e4-b5e29cb683a6,articles/#{article.id}"
      end
    end

    after do
      tempfile.unlink
      ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
    end

    it 'returns redirect mapping' do
      expect(helper.redirect_lookup('uuid', '02fc897a-12b6-4b81-91e4-b5e29cb683a6').to_h).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
      expect(helper.redirect_lookup('new_path', "articles/#{article.id}").to_h).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
    end
  end
end
