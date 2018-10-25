require "rails_helper"

RSpec.describe 'OAI-PMH catalog endpoint' do
  let(:repo_name) { 'Carolina Digital Repository' }
  let(:format) { 'oai_dc' }
  let(:limit) { 10 }
  let(:provider_config) { { repository_name: repo_name } }
  let(:document_config) { { limit: limit } }
  let(:oai_config) { { provider: provider_config, document: document_config } }
  let(:timestamps) { Array.new(0) }


  before do
    CatalogController.configure_blacklight do |config|
      config.oai = oai_config
    end

    solrRecords = ActiveFedora::SolrService.get('has_model_ssim:(Dissertation OR Article OR MastersPaper OR '+
                                                    'HonorsThesis OR Journal OR DataSet OR Multimed OR ScholarlyWork '+
                                                    'OR General OR Artwork) AND visibility_ssi:open', rows: 100)
    solrRecords['response']['docs'].each do |doc|
      timestamps << doc['timestamp']
    end
    timestamps.sort!
  end

  describe 'root page' do
    it 'displays an error message about missing verb' do
      get oai_catalog_path
      expect(response.body).to include('not a legal OAI-PMH verb')
    end
  end

  describe 'Identify verb' do
    scenario 'displays repository information' do
      get oai_catalog_path(verb: 'Identify')
      expect(response.body).to include(repo_name)
    end

    context 'as a POST request' do
      scenario 'displays repository information' do
        post oai_catalog_path(verb: 'Identify')
        expect(response.body).to include(repo_name)
      end
    end
  end

  describe 'ListRecords verb', :vcr do
    scenario 'displays a limited list of records' do
      get oai_catalog_path(verb: 'ListRecords', metadataPrefix: format)
      records = xpath '//xmlns:record'

      expect(records.count).to eq limit
    end

    context 'when number of records exceeds document limit' do
      let(:document_config) { { limit: 25 } }

      scenario 'a resumption token is provided' do
        params = { verb: 'ListRecords', metadataPrefix: format }
        expected_token = 'oai_dc.f('+Time.parse(timestamps.first).utc.iso8601+').u('+
            (Time.parse(timestamps.last)).utc.iso8601+').t('+timestamps.count.to_s+'):25'

        get oai_catalog_path(params)
        token = xpath '//xmlns:resumptionToken'
        records = xpath '//xmlns:record'

        expect(records.count).to be 25
        expect(token.text).to eq expected_token
      end

      scenario 'a resumption token displays the next page of records' do
        # This test checks the last page of records instead of the second
        page = (timestamps.count/25).floor * 25
        params = { verb: 'ListRecords',
                   resumptionToken: 'oai_dc.f('+Time.parse(timestamps.first).utc.iso8601+').u('+
                       (Time.parse(timestamps.last)).utc.iso8601+').t('+timestamps.count.to_s+'):'+page.to_s }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to be(timestamps.count % 25)
      end

      scenario 'the last page of records provides an empty resumption token' do
        params = { verb: 'ListRecords', resumptionToken: 'oai_dc.f('+Time.parse(timestamps.first).utc.iso8601+').u('+
            Time.parse(timestamps.last).utc.iso8601+').t(30):25' }

        get oai_catalog_path(params)
        token = xpath '//xmlns:resumptionToken'

        expect(token.count).to be 1
        expect(token.text).to be_empty
      end
    end

    context 'with a set' do
      let(:document_config) { { set_model: LanguageSet, set_fields: [{ label: 'language', solr_field: 'language_label_tesim' }] } }

      scenario 'only records from the set are returned' do
        params = { verb: 'ListRecords', metadataPrefix: format, set: 'language:japanese' }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to be 2
      end
    end

    context 'with a from date' do
      scenario 'only records with a timestamp after the date are shown' do
        params = { verb: 'ListRecords', metadataPrefix: format,
                   from: Time.parse(timestamps[timestamps.count-2]).utc.iso8601 }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to be 2
        expect(response.body).to include(Time.parse(timestamps[timestamps.count-1]).utc.iso8601)
        expect(response.body).to include(Time.parse(timestamps[timestamps.count-2]).utc.iso8601)
        expect(response.body).not_to include(Time.parse(timestamps[timestamps.count-3]).utc.iso8601)
      end

      context 'and an until date' do
        scenario 'shows records between the dates' do
          params = { verb: 'ListRecords', metadataPrefix: format,
                     from: Time.parse(timestamps[3]).utc.iso8601,
                     until: Time.parse(timestamps[8]).utc.iso8601 }

          get oai_catalog_path(params)
          records = xpath '//xmlns:record'

          expect(records.count).to be 6
          expect(response.body).to include(Time.parse(timestamps[5]).utc.iso8601)
          # Should only include the first 10 items as per the limit
          expect(response.body).not_to include(Time.parse(timestamps[10]).utc.iso8601)
          expect(response.body).not_to include(Time.parse(timestamps[15]).utc.iso8601)
        end
      end
    end

    context 'with an until date' do
      scenario 'only records with a timestamp before the date are shown' do
        params = { verb: 'ListRecords', metadataPrefix: format, until: Time.parse(timestamps[0]).utc.iso8601 }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to be 1
        expect(response.body).to include(Time.parse(timestamps[0]).utc.iso8601)
        expect(response.body).not_to include(Time.parse(timestamps[1]).utc.iso8601)
      end
    end
  end

  describe 'GetRecord verb', :vcr do
    solrRecords = ActiveFedora::SolrService.get('has_model_ssim:Article', rows: 50)
    oai_identifier =  solrRecords['response']['docs'][0]['id']

    let(:params) { { verb: 'GetRecord', metadataPrefix: format, identifier: identifier } }
    let(:identifier) { 'oai:localhost:'+oai_identifier }

    scenario 'displays a single record' do
      get oai_catalog_path(params)
      records = xpath '//xmlns:record'

      expect(records.count).to be 1
      expect(response.body).to include(identifier)
    end

    # Not currently implemented in official gem
    # context 'with an invalid identifier' do
    #   let(:identifier) { ':not_a_valid_id' }
    #
    #   it 'returns an error response' do
    #     get oai_catalog_path(params)
    #     expect(response.body).to include('idDoesNotExist')
    #   end
    # end
  end

  describe 'ListSets verb' do
    context 'without set configuration' do
      scenario 'shows that no sets exist' do
        get oai_catalog_path(verb: 'ListSets')
        expect(response.body).to include('This repository does not support sets.')
      end
    end

    context 'with set configuration', :vcr do
      let(:document_config) { { set_model: LanguageSet, set_fields: [{ label: 'language', solr_field: 'language_label_tesim' }] } }

      scenario 'shows all sets' do
        get oai_catalog_path(verb: 'ListSets')
        sets = xpath '//xmlns:set'
        expect(sets.count).to be 2 # There are currently sample documents in English and Japanese
      end

      scenario 'shows the correct verb' do
        get oai_catalog_path(verb: 'ListSets')
        expect(response.body).to include('request verb="ListSets"')
      end

      context 'where sets include descriptions' do
        let(:document_config) { { set_model: LanguageSet, set_fields: [{ label: 'language', solr_field: 'language_label_tesim' }] } }

        scenario 'shows the set description object' do
          get oai_catalog_path(verb: 'ListSets')
          descriptions = xpath '//xmlns:set/xmlns:setDescription/oai_dc:dc/dc:description',
                               'xmlns' => 'http://www.openarchives.org/OAI/2.0/',
                               'dc' => 'http://purl.org/dc/elements/1.1/',
                               'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/'

          expect(descriptions.count).to be 2
          expect(descriptions[0].text).to eq('This set includes files in the English language.')
          expect(descriptions[1].text).to eq('This set includes files in the Japanese language.')
        end
      end
    end
  end

  describe 'ListMetadataFormats verb' do
    scenario 'lists the oai_dc format' do
      get oai_catalog_path(verb: 'ListMetadataFormats')
      expect(response.body).to include('<metadataPrefix>'+format+'</metadataPrefix>')
    end
  end

  describe 'ListIdentifiers verb' do
    solrRecords = ActiveFedora::SolrService.get('has_model_ssim:Article', rows: 50, sort: 'timestamp asc')
    # The limit is currently 10, so we should expect to get the first 10 items
    oai_identifier1 =  solrRecords['response']['docs'][0]['id']
    oai_identifier2 =  solrRecords['response']['docs'][9]['id']

    let(:expected_ids) { %W(oai:localhost:#{oai_identifier1} oai:localhost:#{oai_identifier2}) }

    scenario 'lists identifiers for works' do
      get oai_catalog_path(verb: 'ListIdentifiers', metadataPrefix: format)
      expect(response.body).to include(*expected_ids)
    end
  end

  def xpath(str, opts = nil)
    Nokogiri::XML(response.body).xpath(str, opts)
  end
end
