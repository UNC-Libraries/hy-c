# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsQueryService do
  let(:dimensions_query_response_fixture) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_query_response.json', __FILE__))
  end

  let(:dimensions_query_response_fixture_non_doi) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_query_response_non_doi.json', __FILE__))
  end

  let(:service) { described_class.new }

  before do
    ActiveFedora::Cleaner.clean!
    ENV['DIMENSIONS_API_KEY'] = 'test_api_key'
    stub_request(:post, 'https://app.dimensions.ai/api/auth')
        .with(
            body: { 'key' => ENV['DIMENSIONS_API_KEY'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
            )
            .to_return(status: 200, body: {token: 'test_token'}.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  after do
    ActiveFedora::Cleaner.clean!
    ENV.delete('DIMENSIONS_API_KEY')
  end

  describe '#retrieve_token' do
    it 'raises and logs an error if token retrieval returns a status code that is not 200' do
      allow(Rails.logger).to receive(:error)
      response_status = 500
      response_body = 'Internal Server Error'
      stub_request(:post, 'https://app.dimensions.ai/api/auth')
        .to_return(status: response_status, body: response_body)

      expect { service.retrieve_token }.to raise_error(Tasks::DimensionsQueryService::DimensionsTokenRetrievalError)

      # Check if the error message has been logged
      expect(Rails.logger).to have_received(:error).with("DimensionsTokenRetrievalError: Failed to retrieve Dimensions API Token. Status code #{response_status}, response body: #{response_body}")
    end

    it 'returns a token' do
      token = service.retrieve_token
      expect(token).to eq('test_token')
    end
  end

  describe '#query_dimensions' do

    with_doi_clause = lambda { |with_doi| with_doi ? 'where doi is not empty' : 'where doi is empty' }
    query_template = <<~QUERY
          search publications %{with_doi_clause} in raw_affiliations#{' '}
          for """
          "University of North Carolina, Chapel Hill" OR "UNC"
          """#{'  '}
          return publications[basics + extras]
          limit %{page_size}
          skip %{skip}
        QUERY

    it 'raises and logs an error if the query returns a status code that is not 403 or 200' do
      allow(Rails.logger).to receive(:error)
      response_status = 500
      response_body = 'Internal Server Error'
      stub_request(:post, 'https://app.dimensions.ai/api/dsl')
        .to_return(status: response_status, body: response_body)

      expect { service.query_dimensions }.to raise_error(Tasks::DimensionsQueryService::DimensionsPublicationQueryError)

      # Check if the error message has been logged
      expect(Rails.logger).to have_received(:error).with("HTTParty error during Dimensions API query: Failed to retrieve UNC affiliated articles from dimensions. Status code #{response_status}, response body: #{response_body}")
    end

    # Checks that the function only retries once to prevent infinite loops
    it 'raises and logs an error if the query returns another 403 status code after a token refresh' do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)

      unauthorized_status = 403
      server_error_status = 500
      unauthorized_body = 'Unauthorized'
      stub_request(:post, 'https://app.dimensions.ai/api/dsl')
        .to_return({status: unauthorized_status, body: unauthorized_body}, {status: unauthorized_status, body: unauthorized_body})

      expect { service.query_dimensions }.to raise_error(Tasks::DimensionsQueryService::DimensionsPublicationQueryError)
      expect(WebMock).to have_requested(:post, 'https://app.dimensions.ai/api/auth').times(2)
      expect(Rails.logger).to have_received(:warn).with('Received 403 Forbidden error. Retrying after token refresh.').once

      # Check if the error message has been logged
      expect(Rails.logger).to have_received(:error).with('HTTParty error during Dimensions API query: Retry attempted after token refresh failed with 403 Forbidden error')
    end

    # Simulating token reretrieval and retry after expiration during query
    it 'refreshes the token and retries if query returns a 403' do
      allow(Rails.logger).to receive(:warn)
      dimensions_pagination_query_responses = [
        File.read(File.expand_path('../../../fixtures/files/dimensions_pagination_query_response_1.json', __FILE__)),
        File.read(File.expand_path('../../../fixtures/files/dimensions_pagination_query_response_2.json', __FILE__))
      ]
      query_strings = [query_template % { with_doi_clause: with_doi_clause.call(true), page_size: 100, skip: 0 },
                      query_template % {  with_doi_clause: with_doi_clause.call(true), page_size: 100, skip: 100 }]

      stub = stub_request(:post, 'https://app.dimensions.ai/api/dsl')
      .with(
        body: query_strings[0],
        headers: { 'Content-Type' => 'application/json' }
      )
      .to_return(status: 200, body: dimensions_pagination_query_responses[0], headers: { 'Content-Type' => 'application/json' })
      .times(1)

      # The first request will return a 403 error, the second request will return a 200 response
      stub = stub_request(:post, 'https://app.dimensions.ai/api/dsl')
      .with(
        body: query_strings[1],
        headers: { 'Content-Type' => 'application/json' }
      )
      .to_return({ status: 403, body: 'Unauthorized' },
      { status: 200, body: dimensions_pagination_query_responses[1], headers: { 'Content-Type' => 'application/json' }})
      .times(2)

      publications = service.query_dimensions(with_doi: true)
      expect(WebMock).to have_requested(:post, 'https://app.dimensions.ai/api/dsl').times(3)
      expect(WebMock).to have_requested(:post, 'https://app.dimensions.ai/api/auth').times(2)
      expect(Rails.logger).to have_received(:warn).with('Received 403 Forbidden error. Retrying after token refresh.').once

       # Combine the publications from all pages for comparison
      expected_publications = dimensions_pagination_query_responses.flat_map { |response| JSON.parse(response)['publications'] }

       # Check if every publication in expected_publications is present in the retrieved publications
      expected_publications.each do |expected_publication|
        expect(publications).to include(expected_publication)
      end
    end

    it 'paginates to retrieve all articles meeting search criteria' do
      start = 0
      query_strings = []
      page_size = 100

      dimensions_pagination_query_responses = [
        File.read(File.expand_path('../../../fixtures/files/dimensions_pagination_query_response_1.json', __FILE__)),
        File.read(File.expand_path('../../../fixtures/files/dimensions_pagination_query_response_2.json', __FILE__))
      ]

      # Stub the requests for each page
      dimensions_pagination_query_responses.each_with_index do |response_body, index|
        query_string = query_template % { with_doi_clause: with_doi_clause.call(true), page_size: page_size, skip: index * page_size }

        stub_request(:post, 'https://app.dimensions.ai/api/dsl')
          .with(
            body: query_string,
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      publications = service.query_dimensions(with_doi: true)

      # Combine the publications from all pages for comparison
      expected_publications = dimensions_pagination_query_responses.flat_map { |response| JSON.parse(response)['publications'] }

      # Check if every publication in expected_publications is present in the retrieved publications
      expected_publications.each do |expected_publication|
        expect(publications).to include(expected_publication)
      end
    end

    it 'returns unc affiliated articles that have dois' do
      query_string = query_template % { with_doi_clause: with_doi_clause.call(true), page_size: 100, skip: 0 }

      stub_request(:post, 'https://app.dimensions.ai/api/dsl')
      .with(
          body: query_string,
          headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: dimensions_query_response_fixture, headers: { 'Content-Type' => 'application/json' })

      publications = service.query_dimensions
      expected_publications = JSON.parse(dimensions_query_response_fixture)['publications']
      expect(publications).to eq(expected_publications)
    end

    it 'returns unc affiliated articles that do not have dois if specified' do
      query_string = query_template % { with_doi_clause: with_doi_clause.call(false), page_size: 100, skip: 0 }

      stub_request(:post, 'https://app.dimensions.ai/api/dsl')
      .with(
          body: query_string,
          headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: dimensions_query_response_fixture_non_doi, headers: { 'Content-Type' => 'application/json' })

      publications = service.query_dimensions(with_doi: false)
      expected_publications = JSON.parse(dimensions_query_response_fixture_non_doi)['publications']
      expect(publications).to eq(expected_publications)
    end
  end

  describe '#deduplicate_publications' do
    let(:dimensions_publications) { JSON.parse(dimensions_query_response_fixture)['publications'] }
    let(:dimensions_publications_without_dois) { JSON.parse(dimensions_query_response_fixture_non_doi)['publications'] }

    it 'removes publications with duplicate dois' do
      # Create two documents with dois that are the same as the first two publications in the test fixture
      test_fixture_dois = dimensions_publications.map { |pub| pub['doi'] }

      documents =
        [{ id: '1111',
        doi_tesim: ["https://doi.org/#{test_fixture_dois[0]}"] },
        { id: '2222',
        identifier_tesim: ["PMID: 12345678, https://doi.org/#{test_fixture_dois[1]}"]}]
      Hyrax::SolrService.add(documents[0..1], commit: true)

      new_publications = service.deduplicate_publications(true, dimensions_publications)

      # Expecting that the two documents with dois that are the same as the first two publications in the test fixture have been removed
      expect(new_publications.map { |pub| pub['doi'] }) .not_to include([test_fixture_dois[0..1]])
      expect(new_publications.count).to eq(1)
      expect(new_publications.first['doi']).to eq(test_fixture_dois[2])
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'removes publications with duplicate titles' do
      # Create two documents with titles that are the same as the first two publications in the test fixture
      # Using publications without dois since deduplicate will default to using the other unique identifiers if there is no doi
      test_fixture_titles = dimensions_publications_without_dois.map { |pub| pub['title'] }

      documents =
        [{ id: '1111',
        title_tesim: [test_fixture_titles[0]] },
        { id: '2222',
        title_tesim: [test_fixture_titles[1]]}]

      Hyrax::SolrService.add(documents[0..1], commit: true)

      new_publications = service.deduplicate_publications(false, dimensions_publications_without_dois)

      # Expecting that the two documents with titles that are the same as the first two publications in the test fixture have been removed
      expect(new_publications.map { |pub| pub['title'] }) .not_to include(test_fixture_titles[0..1])
      expect(new_publications.count).to eq(1)
      expect(new_publications.first['title']).to eq(test_fixture_titles[2])
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'removes publications with duplicate pmids' do
      # Create two documents with pmids that are the same as the first two publications in the test fixture
      # Using publications without dois since deduplicate will default to using the other unique identifiers if there is no doi
      test_fixture_pmids = dimensions_publications_without_dois.map { |pub| pub['pmid'] }

      documents =
        [{ id: '1111',
        identifier_tesim: ["PMID: #{test_fixture_pmids[0]}"]},
        { id: '2222',
        identifier_tesim: ["PMID: #{test_fixture_pmids[1]}"]}]
      Hyrax::SolrService.add(documents[0..1], commit: true)

      new_publications = service.deduplicate_publications(false, dimensions_publications_without_dois)

      expect(new_publications.count).to eq(1)
      expect(new_publications.first['id']).to eq(dimensions_publications_without_dois[2]['id'])
      # Expecting that none of the publications have been marked for review
      expect(new_publications.map { |pub| pub['marked_for_review'] }.all?).to be_falsy
    end

    it 'removes publications with duplicate pmcids' do
      # Create one document with pmcids that's the same as the only publication that has one in the test fixture
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
      # Spoof publications with no unique identifiers
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
