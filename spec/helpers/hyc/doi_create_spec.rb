require 'rails_helper'

RSpec.describe Hyc::DoiCreate do
  describe '#initialize' do
    context'when no row value is specified'do
      it'sets class variables'do
        doi_create = Hyc::DoiCreate.new

        expect(doi_create.as_json['rows']).to eq 1000
        expect(doi_create.as_json['doi_prefix']).to eq'10.5077'
        expect(doi_create.as_json['doi_creation_url']).to eq'https://api.test.datacite.org/dois'
        expect(doi_create.as_json['doi_url_base']).to eq'https://handle.test.datacite.org'
        expect(doi_create.as_json['doi_user']).not_to be_nil
        expect(doi_create.as_json['doi_password']).not_to be_nil
      end
    end

    context'when a row value is specified'do
      it'sets class variables'do
        doi_create = Hyc::DoiCreate.new(10)

        expect(doi_create.as_json['rows']).to eq 10
        expect(doi_create.as_json['doi_prefix']).to eq'10.5077'
        expect(doi_create.as_json['doi_creation_url']).to eq'https://api.test.datacite.org/dois'
        expect(doi_create.as_json['doi_url_base']).to eq'https://handle.test.datacite.org'
        expect(doi_create.as_json['doi_user']).not_to be_nil
        expect(doi_create.as_json['doi_password']).not_to be_nil
      end
    end
  end

  describe '#doi_request' do
    it 'returns datacite record information' do
      # return minted doi in response
      stub_request(:any, /datacite/).to_return(body: {data: {id: '10.5077/0001',
                                                             type: 'dois',
                                                             attributes: { doi: '10.5077/0001'}}}.to_json.to_s)

      data = { "data": { "type": "dois",
                         "attributes": { "prefix": "10.5077",
                                         titles: [{ title: 'new work' }],
                                         types: { resourceType: 'Article', resourceTypeGeneral: 'Text'},
                                         url: "#{ENV['HYRAX_HOST']}/concern/articles/d7f59f11-a35b-41cd-a7d9-77f36738b728",
                                         event: 'publish',
                                         schemaVersion: 'http://datacite.org/schema/kernel-4' } } }

      response = described_class.new.doi_request(data)
      expect(JSON.parse(response.body)['data']['id']).to eq '10.5077/0001'
    end
  end

  describe '#format_data' do
    let(:article) do
      Article.new(title: ['new article'],
                  date_issued: DateTime.now,
                  id: 'd7f59f11-a35b-41cd-a7d9-77f36738b728',
                  resource_type: ['Article'],
                  funder: ['a funder'],
                  subject: ['subject1', 'subject2'],
                  abstract: ['a description'],
                  extent: ['some extent'],
                  language_label: ['English'],
                  rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/')
    end
    let(:honors_thesis) do
      HonorsThesis.new(title: ['new thesis'],
                       date_issued: DateTime.now,
                       id: 'd7f59f11-a35b-41cd-a7d9-77f36738b728',
                       resource_type: ['Video', 'Honors Thesis', 'Journal'],
                       creators_attributes: [{name: 'Person, Test',
                                              affiliation: 'Department of Biology',
                                              orcid: 'some orcid'},
                                             {name: 'Person, Non-UNC',
                                              other_affiliation: 'NCSU'}],
                       publisher: ['Some Publisher'])
    end

    context 'for an article' do
      it 'includes a correct url' do
        result = described_class.new.format_data(article)
        expect(JSON.parse(result)['data']['attributes']['url']).to eq "#{ENV['HYRAX_HOST']}/concern/articles/d7f59f11-a35b-41cd-a7d9-77f36738b728"
        expect(JSON.parse(result)['data']['attributes']['titles']).to match_array [{'title' => 'new article'}]
        expect(JSON.parse(result)['data']['attributes']['publicationYear']).to eq Date.today.year.to_s
        expect(JSON.parse(result)['data']['attributes']['types']['resourceType']).to eq 'Article'
        expect(JSON.parse(result)['data']['attributes']['types']['resourceTypeGeneral']).to eq 'Text'
        expect(JSON.parse(result)['data']['attributes']['creators']['name']).to eq 'The University of North Carolina at Chapel Hill University Libraries'
        expect(JSON.parse(result)['data']['attributes']['creators']['nameType']).to eq 'Organizational'
        expect(JSON.parse(result)['data']['attributes']['publisher']).to eq 'The University of North Carolina at Chapel Hill University Libraries'
        expect(JSON.parse(result)['data']['attributes']['descriptions']).to match_array [{'description' => 'a description', 'descriptionType' => 'Abstract'}]
        expect(JSON.parse(result)['data']['attributes']['subjects']).to match_array [{'subject' => 'subject1'}, {'subject' => 'subject2'}]
        expect(JSON.parse(result)['data']['attributes']['sizes']).to match_array ['some extent']
        expect(JSON.parse(result)['data']['attributes']['language']).to eq 'English'
        expect(JSON.parse(result)['data']['attributes']['rightsList']['rights']).to eq 'In Copyright'
        expect(JSON.parse(result)['data']['attributes']['rightsList']['rightsUri']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      end
    end

    context 'for an honors thesis' do
      it 'includes a correct url' do
        result = described_class.new.format_data(honors_thesis)
        expect(JSON.parse(result)['data']['attributes']['url']).to eq "#{ENV['HYRAX_HOST']}/concern/honors_theses/d7f59f11-a35b-41cd-a7d9-77f36738b728"
        expect(JSON.parse(result)['data']['attributes']['titles']).to match_array [{'title' => 'new thesis'}]
        expect(JSON.parse(result)['data']['attributes']['publicationYear']).to eq Date.today.year.to_s
        # method uses first element in array, and rdf does not preserve order
        expect(['Video', 'Honors Thesis', 'Journal']).to include JSON.parse(result)['data']['attributes']['types']['resourceType']
        expect(['Audiovisual', 'Text']).to include JSON.parse(result)['data']['attributes']['types']['resourceTypeGeneral']
        expect(JSON.parse(result)['data']['attributes']['creators']).to match_array [{'name' => 'Person, Test',
                                                                                      'nameType' => 'Personal',
                                                                                      'affiliation' => ['College of Arts and Sciences', 'Department of Biology'],
                                                                                      'nameIdentifiers' => [{'nameIdentifier' => 'some orcid',
                                                                                                            'nameIdentifierScheme' => 'ORCID'}]},
                                                                                      {'name' => 'Person, Non-UNC',
                                                                                       'nameType' => 'Personal',
                                                                                       'affiliation' => ['NCSU']}]
        expect(JSON.parse(result)['data']['attributes']['publisher']).to eq 'Some Publisher'
      end
    end
  end

  describe '#create_doi' do
    it 'mints doi for record' do
      # return minted doi in response
      stub_request(:any, /datacite/).to_return(body: {data: {id: '10.5077/0001',
                                                             type: 'dois',
                                                             attributes: { doi: '10.5077/0001'}}}.to_json.to_s)

      general_work = General.create(title: ['new general work'])
      expect(general_work.doi).to be_nil

      described_class.new.create_doi({'id' => general_work.id})
      general_work.reload
      expect(general_work.doi).to eq 'https://handle.test.datacite.org/10.5077/0001'
    end
  end

  describe '#create_batch_doi' do
    it 'calls create_doi' do
      expect(Hyc::DoiCreate.new(1).create_batch_doi).to exit(0)
    end
  end
end
