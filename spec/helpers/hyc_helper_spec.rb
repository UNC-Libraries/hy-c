# frozen_string_literal: true
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

  describe '#format_affiliation_facet' do
    before do
      # Configure QA to use fixtures
      qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
      allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
    end

    context 'with valid facet value' do
      let(:facet_value) { 'Department of Chemistry' }

      it 'returns the short label for the facet value' do
        expect(helper.format_affiliation_facet(facet_value)).to eq 'Test short Department of Chemistry'
      end
    end

    context 'with array facet value' do
      let(:facet_value) { ['Department of Chemistry', 'Carolina Center for Genome Sciences'] }

      it 'returns the short label for the facet value' do
        expect(helper.format_affiliation_facet(facet_value)).to eq ['Test short Department of Chemistry', 'Test short Carolina Center for Genome Sciences']
      end
    end

    context 'with invalid facet value' do
      let(:invalid_facet_value) { 'not-a-department' }

      it 'returns the original facet value' do
        expect(helper.format_affiliation_facet(invalid_facet_value)).to eq invalid_facet_value
      end
    end
  end
end
