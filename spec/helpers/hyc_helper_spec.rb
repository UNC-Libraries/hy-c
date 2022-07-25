require 'rails_helper'

RSpec.describe HycHelper do
  describe '#language_links' do
    context 'with valid options' do
      let(:options) { { value: ['http://id.loc.gov/vocabulary/iso639-2/eng'] } }

      it 'returns a link to a language search' do
        expect(helper.language_links(options)).to eq '<a href="/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng">English</a>'
      end
    end

    context 'with invalid options' do
      let(:invalid_options) { { value: ['invalid'] } }

      it 'returns nil if language key is not found' do
        expect(helper.language_links(invalid_options)).to eq nil
      end
    end
  end

  describe '#language_links_facets' do
    context 'with valid options' do
      let(:options) { 'http://id.loc.gov/vocabulary/iso639-2/eng' }

      it 'returns a link to a language search' do
        expect(helper.language_links_facets(options)).to eq 'English'
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
    let(:tempfile) { Tempfile.new('redirect_uuids.csv', 'spec/fixtures/') }
    let(:article) { Article.create(title: ['new article'], visibility: 'open') }

    before do
      File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
        f.puts 'uuid,new_path'
        f.puts "02fc897a-12b6-4b81-91e4-b5e29cb683a6,articles/#{article.id}"
      end
    end

    after do
      tempfile.unlink
      File.delete('spec/fixtures/redirect_uuids.csv') if File.exist?('spec/fixtures/redirect_uuids.csv')
    end

    around do |example|
      cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
      Rails.cache.clear
      ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
      example.run
      ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
    end

    it 'returns redirect mapping' do
      expect(helper.redirect_lookup('uuid', '02fc897a-12b6-4b81-91e4-b5e29cb683a6')).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
      expect(helper.redirect_lookup('uuid', 'not_an_id')).to be_nil
      expect(helper.redirect_lookup('new_path', "articles/#{article.id}")).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
      expect(helper.redirect_lookup('new_path', article.id)).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
      expect(helper.redirect_lookup('new_path', 'justmadethisup')).to be_nil
    end

    it 'raises error when invalid column specified' do
      expect { helper.redirect_lookup('not_valid', '02fc897a-12b6-4b81-91e4-b5e29cb683a6') }.to raise_error(ArgumentError)
    end

    context 'with multiple mappings' do
      before do
        File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
          f.puts 'uuid,new_path'
          f.puts "02fc897a-12b6-4b81-91e4-b5e29cb683a6,articles/#{article.id}"
          f.puts "b19ac193-3fc1-43b5-ac52-b4828ec0afdb,parent/#{article.id}/file_sets/ff365f05d"
        end
      end

      it 'returns redirect mapping' do
        expect(helper.redirect_lookup('uuid', '02fc897a-12b6-4b81-91e4-b5e29cb683a6')).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
        expect(helper.redirect_lookup('uuid', 'b19ac193-3fc1-43b5-ac52-b4828ec0afdb')).to include('uuid' => 'b19ac193-3fc1-43b5-ac52-b4828ec0afdb', 'new_path' => "parent/#{article.id}/file_sets/ff365f05d")
        expect(helper.redirect_lookup('new_path', "articles/#{article.id}")).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
        expect(helper.redirect_lookup('new_path', article.id)).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
        expect(helper.redirect_lookup('new_path', "parent/#{article.id}/file_sets/ff365f05d")).to include('uuid' => 'b19ac193-3fc1-43b5-ac52-b4828ec0afdb', 'new_path' => "parent/#{article.id}/file_sets/ff365f05d")
        expect(helper.redirect_lookup('new_path', 'ff365f05d')).to include('uuid' => 'b19ac193-3fc1-43b5-ac52-b4828ec0afdb', 'new_path' => "parent/#{article.id}/file_sets/ff365f05d")
      end
    end
  end
end
