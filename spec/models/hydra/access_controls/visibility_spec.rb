# frozen_string_literal: true
require 'rails_helper'

describe Hydra::AccessControls::Visibility do
  describe '#visibility' do
    context 'with a new article' do
      let(:article) { Article.new }

      it 'has default public visibility' do
        expect(article.visibility).to eq 'open'
      end
    end

    context 'with an existing article with no defined read groups' do
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
  end
end