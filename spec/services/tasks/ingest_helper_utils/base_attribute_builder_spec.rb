# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::BaseAttributeBuilder, type: :model do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor_onyen) { 'admin' }
  let(:article) { Article.new }
  let(:metadata) { Nokogiri::XML('<root></root>') }

  let(:stub_builder_class) do
    Class.new(described_class) do
      def generate_authors
        [{ 'name' => 'Doe, John', 'orcid' => '', 'index' => '0', 'other_affiliation' => '' }]
      end

      def apply_additional_basic_attributes(article)
        article.title = ['Stub Title']
      end

      def set_journal_attributes(article)
        article.journal_title = 'Test Journal'
      end

      def set_identifiers(article)
        article.identifier = ['PMID: 123456']
      end

      def format_publication_identifiers
        ['PMID: 123456']
      end

      def retrieve_author_affiliations(_hash, _author)
        nil
      end

      def get_date_issued
        '2025-01-01'
      end
    end
  end

  let(:builder) { stub_builder_class.new(metadata, admin_set, depositor_onyen) }

  describe '#populate_article_metadata' do
    it 'calls metadata population steps and returns the article' do
      expect(builder).to receive(:set_rights_and_types).and_call_original
      expect(builder).to receive(:set_basic_attributes).and_call_original
      expect(builder).to receive(:set_journal_attributes).and_call_original
      expect(builder).to receive(:set_identifiers).and_call_original

      result = builder.populate_article_metadata(article)

      expect(result).to eq(article)
      expect(article.admin_set).to eq(admin_set)
      expect(article.depositor).to eq(depositor_onyen)
      expect(article.resource_type).to eq(['Article'])
      expect(article.title).to eq(['Stub Title'])
      expect(article.journal_title).to eq('Test Journal')
      expect(article.identifier).to include('PMID: 123456')
    end
  end

  describe '#set_rights_and_types' do
    it 'assigns default rights and types' do
      builder.send(:set_rights_and_types, article)
      expect(article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(article.rights_statement_label).to eq('In Copyright')
      expect(article.dcmi_type).to eq(['http://purl.org/dc/dcmitype/Text'])
    end
  end

  describe 'abstract methods' do
    subject(:abstract_builder) { described_class.new(metadata, admin_set, depositor_onyen) }
    it 'raises NotImplementedError for generate_authors' do
      expect { abstract_builder.send(:generate_authors) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for retrieve_author_affiliations' do
      expect { abstract_builder.send(:retrieve_author_affiliations, {}, nil) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for apply_additional_basic_attributes' do
      expect { abstract_builder.send(:apply_additional_basic_attributes, article) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for get_date_issued' do
      expect { abstract_builder.send(:get_date_issued) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for set_identifiers' do
      expect { abstract_builder.send(:set_identifiers, article) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for format_publication_identifiers' do
      expect { abstract_builder.send(:format_publication_identifiers) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for set_journal_attributes' do
      expect { abstract_builder.send(:set_journal_attributes, article) }.to raise_error(NotImplementedError)
    end
  end
end
