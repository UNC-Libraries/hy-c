# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsQueryService do
  let(:dimensions_query_response) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_query_response.json', __FILE__))
  end

  let(:dimensions_query_response_non_doi) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_query_response_non_doi.json', __FILE__))
  end


  let(:service) { described_class.new }

  before do
    ActiveFedora::Cleaner.clean!
    stub_request(:post, 'https://app.dimensions.ai/api/auth')
        .with(
            body: { 'key' => ENV['DIMENSIONS_API_KEY'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
            )
            .to_return(status: 200, body: {token: 'test_token'}.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  after do
    ActiveFedora::Cleaner.clean!
  end

  describe '#initialize' do
    it 'creates a new instance of the service' do
      expect(service).to be_an_instance_of described_class
    end
  end

  describe '#retrieve_token' do
    it 'returns a token' do
      token = service.retrieve_token
      expect(token).to eq('test_token')
    end
  end

  describe '#query_dimensions' do
    it 'returns unc affiliated articles that have dois' do
      query_string = <<~QUERY
                        search publications where doi is not empty in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications[basics + extras]
                        limit 100
                        skip 0
                    QUERY

      stub_request(:post, 'https://app.dimensions.ai/api/dsl')
      .with(
          body: query_string,
          headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: dimensions_query_response, headers: { 'Content-Type' => 'application/json' })

      publications = service.query_dimensions
      expected_publications = JSON.parse(dimensions_query_response)['publications']
      expect(publications).to eq(expected_publications)
    end

    it 'returns unc affiliated articles that do not have dois if specified' do
      query_string = <<~QUERY
                        search publications where doi is empty in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications[basics + extras]
                        limit 100
                        skip 0
                    QUERY

      stub_request(:post, 'https://app.dimensions.ai/api/dsl')
      .with(
          body: query_string,
          headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: dimensions_query_response_non_doi, headers: { 'Content-Type' => 'application/json' })

      publications = service.query_dimensions(with_doi: false)
      expected_publications = JSON.parse(dimensions_query_response_non_doi)['publications']
      expect(publications).to eq(expected_publications)
    end
  end

  describe '#deduplicate_publications' do
    let(:dimensions_publications) { JSON.parse(dimensions_query_response)['publications'] }
    let(:dimensions_publications_without_dois) { JSON.parse(dimensions_query_response_non_doi)['publications'] }

    it 'removes publications with duplicate dois' do
      documents =
        [{ id: '1111',
        doi_tesim: ["https://doi.org/#{dimensions_publications[0]['doi']}"] },
        { id: '2222',
        doi_tesim: ["https://doi.org/#{dimensions_publications[1]['doi']}"]}]

      Hyrax::SolrService.add([documents[0], documents[1]], commit: true)
      new_publications = service.deduplicate_publications(true, dimensions_publications)
      expect(new_publications.count).to eq(1)
      expect(new_publications.first['id']).to eq(dimensions_publications[2]['id'])
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'removes publications with duplicate titles' do
      documents =
        [{ id: '1111',
        title_tesim: [dimensions_publications_without_dois[0]['title']] },
        { id: '2222',
        title_tesim: [dimensions_publications_without_dois[1]['title']]}]

      Hyrax::SolrService.add([documents[0], documents[1]], commit: true)
      new_publications = service.deduplicate_publications(false, dimensions_publications_without_dois)
      expect(new_publications.count).to eq(1)
      expect(new_publications.first['id']).to eq(dimensions_publications_without_dois[2]['id'])
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'removes publications with duplicate pmids' do
      documents =
        [{ id: '1111',
        identifier_tesim: ["PMID: #{dimensions_publications_without_dois[0]['pmid']}"]},
        { id: '2222',
        identifier_tesim: ["PMID: #{dimensions_publications_without_dois[1]['pmid']}"]}]

      Hyrax::SolrService.add([documents[0], documents[1]], commit: true)
      new_publications = service.deduplicate_publications(false, dimensions_publications_without_dois)
      expect(new_publications.count).to eq(1)
      expect(new_publications.first['id']).to eq(dimensions_publications_without_dois[2]['id'])
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'removes publications with duplicate pmcids' do
      # The only publication in the test fixture with a PMCID is the second one
      documents =
        [{ id: '1111',
        identifier_tesim: ["PMCID: #{dimensions_publications_without_dois[1]['pmcid']}"]}]

      non_pmcid_publication_ids = [dimensions_publications_without_dois[0]['id'], dimensions_publications_without_dois[2]['id']]

      Hyrax::SolrService.add(documents[0], commit: true)
      new_publications = service.deduplicate_publications(false, dimensions_publications_without_dois)
      expect(new_publications.count).to eq(2)
      expect(new_publications.map { |pub| pub['id'] }).to include(*non_pmcid_publication_ids)
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'marks publications for review if it has a unique title, no pmcid, pmid or doi' do
      spoofed_dimensions_publications = [{
        'title' => 'Unique Title', },
      { 'title' => 'Unique Title 2', },
      { 'title' => 'Unique Title 3', }]
      new_publications = service.deduplicate_publications(false, spoofed_dimensions_publications)
      expect(new_publications.count).to eq(3)
      expect(new_publications.map { |pub| pub['title'] }).to include(*spoofed_dimensions_publications.map { |pub| pub['title'] })
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_truthy
    end

  end
end
