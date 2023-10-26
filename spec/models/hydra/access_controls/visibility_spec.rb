# frozen_string_literal: true
require 'rails_helper'

describe Hydra::AccessControls::Visibility do
  describe '#visibility' do
    context 'with a new article' do
      let(:article) { Article.new }

      it 'has default open visibility' do
        expect(article.visibility).to eq 'open'
      end
    end

    context 'with a new article with registered group' do
      let(:article) { Article.new(read_groups: ['registered']) }

      it 'has authenticated visibility' do
        expect(article.visibility).to eq 'authenticated'
      end
    end

    context 'with a new article with private group' do
      let(:article) { Article.new(read_groups: ['private']) }

      it 'has restricted visibility' do
        expect(article.visibility).to eq 'restricted'
      end
    end

    context 'with an existing article with empty read groups' do
      let(:article) do
        FactoryBot.create(
          :article,
          read_groups: []
        )
      end

      it 'has default private visibility' do
        expect(article.visibility).to eq 'restricted'
      end
    end

    context 'with an existing article with registered read group' do
      let(:article) do
        FactoryBot.create(
          :article,
          read_groups: ['registered']
        )
      end

      it 'has authenticated visibility' do
        expect(article.visibility).to eq 'authenticated'
      end
    end

    context 'with an existing article with public read group' do
      let(:article) do
        FactoryBot.create(
          :article,
          read_groups: ['public']
        )
      end

      it 'has open visibility' do
        expect(article.visibility).to eq 'open'
      end
    end
  end
end
