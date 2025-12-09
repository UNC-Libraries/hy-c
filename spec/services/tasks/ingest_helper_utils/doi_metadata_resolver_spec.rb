# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::DoiMetadataResolver do
  let(:doi) { '10.1000/test123' }
  let(:admin_set) { double('AdminSet', id: 'admin_set_1') }
  let(:depositor_onyen) { 'test-user' }

  subject(:resolver) do
    described_class.new(doi: doi, admin_set: admin_set, depositor_onyen: depositor_onyen)
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
  end

  describe '#initialize' do
    it 'sets expected instance variables' do
      expect(resolver.doi).to eq(doi)
      expect(resolver.admin_set).to eq(admin_set)
      expect(resolver.depositor_onyen).to eq(depositor_onyen)
    end
  end

  describe '#fetch_all_metadata' do
    let(:crossref_md) { { 'title' => 'Crossref Title' } }
    let(:openalex_md) { { 'title' => 'OpenAlex Title' } }
    let(:datacite_md) { { 'attributes' => { 'description' => 'DataCite desc' } } }

    before do
      allow(resolver).to receive(:fetch_metadata_for_doi).with(source: 'crossref', doi: doi).and_return(crossref_md)
      allow(resolver).to receive(:fetch_metadata_for_doi).with(source: 'openalex', doi: doi).and_return(openalex_md)
      allow(resolver).to receive(:fetch_metadata_for_doi).with(source: 'datacite', doi: doi).and_return(datacite_md)
    end

    it 'fetches metadata from all three sources' do
      resolver.fetch_all_metadata

      expect(resolver).to have_received(:fetch_metadata_for_doi).with(source: 'crossref', doi: doi)
      expect(resolver).to have_received(:fetch_metadata_for_doi).with(source: 'openalex', doi: doi)
      expect(resolver).to have_received(:fetch_metadata_for_doi).with(source: 'datacite', doi: doi)
    end

    it 'stores metadata in instance variables' do
      resolver.fetch_all_metadata

      expect(resolver.instance_variable_get(:@crossref_md)).to eq(crossref_md)
      expect(resolver.instance_variable_get(:@openalex_md)).to eq(openalex_md)
      expect(resolver.instance_variable_get(:@datacite_md)).to eq(datacite_md)
    end
  end

  describe '#verify_source_available' do
    context 'when both crossref and openalex are available' do
      before do
        resolver.instance_variable_set(:@crossref_md, { 'title' => 'Crossref' })
        resolver.instance_variable_set(:@openalex_md, { 'title' => 'OpenAlex' })
      end

      it 'returns without logging' do
        resolver.verify_source_available
        expect(LogUtilsHelper).not_to have_received(:double_log)
      end
    end

    context 'when crossref is nil but openalex is available' do
      before do
        resolver.instance_variable_set(:@crossref_md, nil)
        resolver.instance_variable_set(:@openalex_md, { 'title' => 'OpenAlex' })
      end

      it 'logs a warning about using OpenAlex' do
        resolver.verify_source_available
        expect(LogUtilsHelper).to have_received(:double_log).with(
          /No metadata found from Crossref.*Using OpenAlex metadata/,
          :warn,
          tag: 'MetadataResolver'
        )
      end
    end

    context 'when openalex is nil but crossref is available' do
      before do
        resolver.instance_variable_set(:@crossref_md, { 'title' => 'Crossref' })
        resolver.instance_variable_set(:@openalex_md, nil)
      end

      it 'logs a warning about using Crossref' do
        resolver.verify_source_available
        expect(LogUtilsHelper).to have_received(:double_log).with(
          /No metadata found from OpenAlex.*Using Crossref metadata/,
          :warn,
          tag: 'MetadataResolver'
        )
      end
    end

    context 'when both crossref and openalex are nil' do
      before do
        resolver.instance_variable_set(:@crossref_md, nil)
        resolver.instance_variable_set(:@openalex_md, nil)
      end

      it 'raises an error' do
        expect { resolver.verify_source_available }.to raise_error(
          /No metadata found from Crossref or OpenAlex for DOI #{doi}/
        )
      end
    end
  end

  describe '#merge_sources' do
    context 'when openalex metadata is available' do
      let(:openalex_md) do
        {
          'title' => 'OpenAlex Title',
          'abstract_inverted_index' => { 'Test' => [0], 'abstract' => [1] },
          'concepts' => [{ 'display_name' => 'Keyword1' }]
        }
      end
      let(:datacite_md) { { 'attributes' => { 'description' => 'DataCite abstract' } } }

      before do
        resolver.instance_variable_set(:@openalex_md, openalex_md)
        resolver.instance_variable_set(:@crossref_md, { 'title' => 'Crossref Title' })
        resolver.instance_variable_set(:@datacite_md, datacite_md)
        allow(resolver).to receive(:generate_openalex_abstract).and_return('Test abstract')
        allow(resolver).to receive(:extract_keywords_from_openalex).and_return(['Keyword1'])
      end

      it 'uses openalex as the base and sets source to openalex' do
        result = resolver.merge_sources
        expect(result['title']).to eq('OpenAlex Title')
        expect(result['source']).to eq('openalex')
      end

      it 'adds openalex abstract' do
        result = resolver.merge_sources
        expect(result['openalex_abstract']).to eq('Test abstract')
        expect(resolver).to have_received(:generate_openalex_abstract).with(openalex_md)
      end

      it 'adds datacite abstract' do
        result = resolver.merge_sources
        expect(result['datacite_abstract']).to eq('DataCite abstract')
      end

      it 'adds openalex keywords' do
        result = resolver.merge_sources
        expect(result['openalex_keywords']).to eq(['Keyword1'])
        expect(resolver).to have_received(:extract_keywords_from_openalex).with(openalex_md)
      end
    end

    context 'when only crossref metadata is available' do
      let(:crossref_md) { { 'title' => 'Crossref Title' } }

      before do
        resolver.instance_variable_set(:@openalex_md, nil)
        resolver.instance_variable_set(:@crossref_md, crossref_md)
        resolver.instance_variable_set(:@datacite_md, nil)
        allow(resolver).to receive(:generate_openalex_abstract).and_return(nil)
        allow(resolver).to receive(:extract_keywords_from_openalex).and_return(nil)
      end

      it 'uses crossref as the base and sets source to crossref' do
        result = resolver.merge_sources
        expect(result['title']).to eq('Crossref Title')
        expect(result['source']).to eq('crossref')
      end
    end

    context 'when datacite has no description' do
      before do
        resolver.instance_variable_set(:@openalex_md, { 'title' => 'Test' })
        resolver.instance_variable_set(:@crossref_md, {})
        resolver.instance_variable_set(:@datacite_md, { 'attributes' => {} })
        allow(resolver).to receive(:generate_openalex_abstract).and_return(nil)
        allow(resolver).to receive(:extract_keywords_from_openalex).and_return(nil)
      end

      it 'does not add datacite_abstract' do
        result = resolver.merge_sources
        expect(result['datacite_abstract']).to be_nil
      end
    end
  end

  describe '#construct_attribute_builder' do
    let(:resolved_md) { { 'source' => 'openalex', 'title' => 'Test' } }

    before do
      resolver.instance_variable_set(:@resolved_md, resolved_md)
    end

    context 'when source is openalex' do
      it 'creates an OpenalexAttributeBuilder' do
        builder_double = double('OpenalexAttributeBuilder')
        allow(Tasks::IngestHelperUtils::SharedAttributeBuilders::OpenalexAttributeBuilder)
          .to receive(:new).with(resolved_md, admin_set, depositor_onyen).and_return(builder_double)

        result = resolver.construct_attribute_builder

        expect(result).to eq(builder_double)
        expect(Tasks::IngestHelperUtils::SharedAttributeBuilders::OpenalexAttributeBuilder)
          .to have_received(:new).with(resolved_md, admin_set, depositor_onyen)
      end
    end

    context 'when source is crossref' do
      let(:resolved_md) { { 'source' => 'crossref', 'title' => 'Test' } }

      it 'creates a CrossrefAttributeBuilder' do
        builder_double = double('CrossrefAttributeBuilder')
        allow(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder)
          .to receive(:new).with(resolved_md, admin_set, depositor_onyen).and_return(builder_double)

        result = resolver.construct_attribute_builder

        expect(result).to eq(builder_double)
        expect(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder)
          .to have_received(:new).with(resolved_md, admin_set, depositor_onyen)
      end
    end
  end

  describe '#resolve_and_build' do
    let(:crossref_md) { { 'title' => 'Crossref' } }
    let(:openalex_md) { { 'title' => 'OpenAlex' } }
    let(:datacite_md) { { 'attributes' => { 'description' => 'DataCite' } } }
    let(:merged_md) { { 'title' => 'OpenAlex', 'source' => 'openalex' } }
    let(:mock_builder) { double('AttributeBuilder') }

    before do
      allow(resolver).to receive(:fetch_metadata_for_doi).with(source: 'crossref', doi: doi).and_return(crossref_md)
      allow(resolver).to receive(:fetch_metadata_for_doi).with(source: 'openalex', doi: doi).and_return(openalex_md)
      allow(resolver).to receive(:fetch_metadata_for_doi).with(source: 'datacite', doi: doi).and_return(datacite_md)
      allow(resolver).to receive(:generate_openalex_abstract).and_return('abstract')
      allow(resolver).to receive(:extract_keywords_from_openalex).and_return(['keyword'])
      allow(Tasks::IngestHelperUtils::SharedAttributeBuilders::OpenalexAttributeBuilder)
        .to receive(:new).and_return(mock_builder)
    end

    it 'executes all steps in order and returns the attribute builder' do
      result = resolver.resolve_and_build

      expect(resolver).to have_received(:fetch_metadata_for_doi).exactly(3).times
      expect(result).to eq(mock_builder)
    end

    it 'makes resolved metadata accessible' do
      resolver.resolve_and_build
      expect(resolver.resolved_metadata).to be_a(Hash)
      expect(resolver.resolved_metadata['source']).to eq('openalex')
    end
  end

  describe '#resolved_metadata' do
    it 'returns the merged metadata' do
      merged = { 'title' => 'Test', 'source' => 'openalex' }
      resolver.instance_variable_set(:@resolved_md, merged)

      expect(resolver.resolved_metadata).to eq(merged)
    end
  end
end
