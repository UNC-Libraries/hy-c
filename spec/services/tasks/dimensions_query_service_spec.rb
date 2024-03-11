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
    context 'when dimensions publications have dois currently in solr' do

      let(:documents) do
        [{ id: '1111',
          doi_tesim: ['https://doi.org/10.5688/ajpe7320']},
        { id: '2222',
          doi_tesim: ['https://doi.org/10.1002/hep.26460']}]
      end

      before do
        Hyrax::SolrService.add([documents[0], documents[1]], commit: true)
      end

      it 'removes publications with dois currently in solr' do
        new_publications = service.deduplicate_publications(true, JSON.parse(dimensions_query_response)['publications'])
        expect(new_publications.count).to eq(1)
        expect(new_publications.first['doi']).to eq('10.1016/j.jaad.2020.06.824')
      end

    end
  end


end
