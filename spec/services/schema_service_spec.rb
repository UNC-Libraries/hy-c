# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SchemaService do
  let(:service) { described_class }

  context 'with a presenter' do
    let(:attributes) do
      { 'id' => '888888',
        'title_tesim' => ['foo'],
        'human_readable_type_tesim' => ['General'],
        'has_model_ssim' => ['General'],
        'abstract_tesim' => ['an abstract'],
        'access_right_tesim' => ['public'],
        'alternative_title_tesim' => ['some title'],
        'copyright_date_tesim' => '2017',
        'creator_display_tesim' => ['index:1||Kelce, Travis||Affiliation: Bowles Center for Alcohol Studies'],
        'contributor_display_tesim' => ['index:1||Swift, Taylor||Other Affiliation: Heartbreak University']
      }
    end

    let(:ability) { nil }
    let(:solr_document) { SolrDocument.new(attributes) }
    let(:request) { double(host: 'example.org', base_url: 'http://example.org') }
    let(:default_presenter) { build_presenter(solr_document) }

    describe '#person_details' do
      it 'returns parsed person details with mapped UNC Affiliation prioritized' do
        person_string = 'index:1||Kelce, Travis||Affiliation: Bowles Center for Alcohol Studies||
          Other Affiliation: Heartbreak University|| ORCID: http://example.org'
        expect(service.person_details(person_string)).to eq({ '@type' => 'Person',
                                                              'name' => 'Kelce, Travis',
                                                              'sameAs' => 'http://example.org',
                                                              'affiliation' => 'School of Medicine, Bowles Center for Alcohol Studies' })
      end
      it 'returns parsed person details with non-mapped UNC Affiliation prioritized' do
        person_string = 'index:1||Kelce, Travis||Affiliation: Kansas City Chiefs||
          Other Affiliation: Heartbreak University|| ORCID: http://example.org'
        expect(service.person_details(person_string)).to eq({ '@type' => 'Person',
                                                              'name' => 'Kelce, Travis',
                                                              'sameAs' => 'http://example.org',
                                                              'affiliation' => 'Kansas City Chiefs' })
      end
      it 'returns parsed person details with Other Affiliation' do
        person_string = 'index:1||Kelce, Travis||Other Affiliation: Heartbreak University|| ORCID: http://example.org'
        expect(service.person_details(person_string)).to eq({ '@type' => 'Person',
                                                              'name' => 'Kelce, Travis',
                                                              'sameAs' => 'http://example.org',
                                                              'affiliation' => 'Heartbreak University' })
      end
      it 'returns blank affiliation if affiliation is a blank string' do
        person_string = 'index:1||Kelce, Travis||Affiliation: ||Other Affiliation: ||ORCID: http://example.org'
        expect(service.person_details(person_string)).to eq({ '@type' => 'Person',
                                                              'name' => 'Kelce, Travis',
                                                              'sameAs' => 'http://example.org',
                                                              'affiliation' => '' })
      end
      it 'returns blank affiliation if there are no affiliations' do
        person_string = 'index:1||Kelce, Travis||ORCID: http://example.org'
        expect(service.person_details(person_string)).to eq({ '@type' => 'Person',
                                                              'name' => 'Kelce, Travis',
                                                              'sameAs' => 'http://example.org',
                                                              'affiliation' => '' })
      end
    end

    describe '#resource_type' do
      it 'returns mapped value if present in schema org yml' do
        expect(service.resource_type('Other')).to eq('http://schema.org/CreativeWork')
      end
      it 'returns original value if not present in schema org yml' do
        expect(service.resource_type('Article')).to eq('Article')
      end
    end

    describe '#about' do
      it 'returns an array with subject hash if present' do
        solr_doc = SolrDocument.new(attributes.merge({ 'subject_tesim' => ['Kpop'] }))
        presenter = build_presenter(solr_doc)
        expect(service.about(presenter)).to eq([{ '@type' => 'Thing', 'name' => 'Kpop' }])
      end
      it 'returns nil if no subject present' do
        expect(service.about(default_presenter)).to eq([])
      end
    end

    describe '#keyword' do
      it 'returns an array with keywords if present' do
        solr_doc = SolrDocument.new(attributes.merge({ 'keyword_tesim' => %w[country kpop] }))
        presenter = build_presenter(solr_doc)
        expect(service.keywords(presenter)).to eq(%w[country kpop])
      end
      it 'returns nil if no keywords present' do
        expect(service.keywords(default_presenter)).to eq([])
      end
    end

    describe '#affiliation' do
      it 'returns unc affiliation if present' do
        expect(service.affiliation('Bowles Center for Alcohol Studies', 'Other Affiliation')).to eq('Bowles Center for Alcohol Studies')
      end
      it 'returns other affiliation if unc affiliation is not present' do
        expect(service.affiliation('', 'Other Affiliation')).to eq('Other Affiliation')
      end
    end

    describe '#language' do
      it 'returns an array with language hash if present' do
        solr_doc = SolrDocument.new(attributes.merge({ 'language_tesim' => ['Korean'] }))
        presenter = build_presenter(solr_doc)
        expect(service.language(presenter)).to eq([{ '@type' => 'Language', 'name' => 'Korean' }])
      end
      it 'returns nil if no language present' do
        expect(service.language(default_presenter)).to eq([])
      end
    end

    describe '#publisher' do
      it 'returns an array with publisher hash if present' do
        solr_doc = SolrDocument.new(attributes.merge({ 'publisher_tesim' => ['UNC Publishing'] }))
        presenter = build_presenter(solr_doc)
        expect(service.publisher(presenter)).to eq([{ '@type' => 'Organization', 'name' => 'UNC Publishing' }])
      end
      it 'returns nil if no publisher present' do
        expect(service.publisher(default_presenter)).to eq([])
      end
    end

    describe '#location' do
      it 'returns a location hash if present' do
        solr_doc = SolrDocument.new(attributes.merge({'based_near_label_tesim' => 'Los Angeles'}))
        presenter = build_presenter(solr_doc)
        expect(service.location(presenter)).to eq({ '@type' => 'Place', 'name' => ['Los Angeles'] })
      end
      it 'returns nil if no based_near_label present' do
        expect(service.location(default_presenter)).to eq(nil)
      end
    end
  end

  describe '#sanitized_value' do
    let(:value) { %w[first second] }
    it 'returns the first value' do
      expect(service.sanitized_value(value)).to eq('first')
    end
    it 'returns if nil' do
      expect(service.sanitized_value(nil)).to eq(nil)
    end
  end

  describe '#plain_text' do
    let(:string) { "<p>Peter Erspamer explores the 'Jewish question' in German literature.</p>" }
    it 'strips all tags from the string' do
      expect(service.plain_text(string)).to eq("Peter Erspamer explores the 'Jewish question' in German literature.")
    end
    it 'returns if nil' do
      expect(service.plain_text(nil)).to eq(nil)
    end
  end

  def build_presenter(solr_doc)
    return Hyrax::WorkShowPresenter.new(solr_doc, ability, request)
  end
end
