require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe AffiliationRemediationService do
  let(:service) { described_class.new(unmappable_affiliations_path) }
  let(:unmappable_affiliations_path) { File.join(fixture_path, 'files', 'short_unmappable_affiliations.csv') }
  let(:unmappable_affiliation_one) { 'University of North Carolina at Chapel Hill. Library' }
  let(:mapped_affiliation_one) { 'University of North Carolina at Chapel Hill. University Libraries' }
  let(:unmappable_affiliation_two) { 'Department of Economics and Curriculum for the Environment and Ecology; University of North Carolina at Chapel Hill' }
  let(:mapped_affiliation_two) { 'Department of Economics' }
  let(:updated_person_hash) do
    {
      'index' => [1],
      'name' => ['creator_1'],
      'orcid' => [],
      'affiliation' => ['University of North Carolina at Chapel Hill. University Libraries'],
      'other_affiliation' => []
    }
  end
  let(:obj) { service.object_by_id(article.id) }
  let(:article_identifier) { '76537342x' }
  let(:article) do
    FactoryBot.create(
      :article,
      id: article_identifier,
      creators_attributes: { '0' => { name: 'creator_1',
                                      affiliation: unmappable_affiliation_one,
                                      index: 1 },
                             '1' => { name: 'creator_2',
                                      affiliation: unmappable_affiliation_two,
                                      index: 2 } }
    )
  end
  let(:work_with_people) do
    General.create(title: ['New General Work with people'],
                   'translators_attributes'.to_sym => { '0' => { name: 'translator_1',
                                                                 affiliation: 'Carolina Center for Genome Sciences',
                                                                 index: 1 },
                                                        '1' => { name: 'translator_2',
                                                                 affiliation: 'Department of Chemistry',
                                                                 index: 2 },
                                                        '2' => { name: 'translator_3',
                                                                 affiliation: 'Unmappable affiliation 1',
                                                                 index: 3 },
                                                        '3' => { name: 'translator_4',
                                                                 affiliation: 'Unmappable affiliation 2',
                                                                 index: 4 } })
  end

  before do
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
  end

  it 'can be instantiated' do
    expect(described_class.new(unmappable_affiliations_path)).to be
  end

  it 'has a list of target ids' do
    expect(service.id_list).to be_a_kind_of(Array)
    expect(service.id_list.first).to be_a_kind_of(String)
  end

  it 'can map from an unmappable affiliation to a mappable affiliation' do
    expect(service.map_to_new_affiliation(unmappable_affiliation_one)).to eq(mapped_affiliation_one)
    expect(service.map_to_new_affiliation(unmappable_affiliation_two)).to eq(mapped_affiliation_two)
  end

  it 'can determine if an affiliation is unmappable' do
    expect(service.mappable_affiliation?(unmappable_affiliation_one)).to eq false
    expect(service.mappable_affiliation?(mapped_affiliation_one)).to eq true
  end

  context 'with multiple affiliations' do
    let(:unmappable_affiliation_one) { 'Departmentrof Chemistry and Neuroscience Center University of North Carolina at Chapel Hill Chapel Hill, NC 27599-3290' }
    let(:mapped_affiliation_one) { ['UNC Neuroscience Center', 'Department of Chemistry'] }

    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      article
    end

    it 'can map from an unmappable affiliation to a mappable affiliation' do
      expect(service.map_to_new_affiliation(unmappable_affiliation_one)).to eq(mapped_affiliation_one)
      # expect(service.map_to_new_affiliation(unmappable_affiliation_two)).to eq(mapped_affiliation_two)
    end

    it 'can update the creator affiliations' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([unmappable_affiliation_one])
      service.update_affiliations(obj)
      obj.reload
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq(mapped_affiliation_one)
    end
  end

  context 'with an article and general work' do
    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      article
      work_with_people
    end

    it 'has a wrapper method' do
      expect do
        service.remediate_all_affiliations
        obj.reload
      end.to(change { obj.creators })
    end
  end

  context 'with an example Article' do
    let(:obj) { service.object_by_id(article.id) }

    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      article
    end

    it 'can find the object associated with an id on the list' do
      expect(obj).to be_a_kind_of(Article)
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([unmappable_affiliation_one])
    end

    it 'limits calls to the DepartmentService' do
      allow(DepartmentsService).to receive(:label)
      service.update_affiliations(obj)
      expect(DepartmentsService).to have_received(:label).with(unmappable_affiliation_one).once
    end

    it 'can update the creator affiliations' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([unmappable_affiliation_one])
      service.update_affiliations(obj)
      obj.reload
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([mapped_affiliation_one])
    end

    it 'can create a new person hash based on original person attributes' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      original_person_hash = first_creator.attributes
      expect(service.map_person_attributes(original_person_hash)).to eq(updated_person_hash)
    end

    it 'keeps the original number of creators' do
      expect(obj.creators.count).to eq 2
      service.update_affiliations(obj)
      obj.reload
      expect(obj.creators.count).to eq 2
    end
  end

  context 'with a general work with a mix of people objects' do
    let(:obj) { service.object_by_id(work_with_people.id) }
    let(:updated_translator_1_hash) do
      {
        'index' => [1],
        'name' => ['translator_1'],
        'orcid' => [],
        'affiliation' => ['Carolina Center for Genome Sciences'],
        'other_affiliation' => []
      }
    end
    let(:updated_translator_3_hash) do
      {
        'index' => [3],
        'name' => ['translator_3'],
        'orcid' => [],
        'affiliation' => [],
        'other_affiliation' => []
      }
    end

    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      work_with_people
    end

    it 'can update the translator affiliations' do
      first_translator = obj.translators.find { |person| person['index'] == [1] }
      expect(obj.translators.count).to eq 4
      expect(first_translator.attributes['affiliation']).to eq(['Carolina Center for Genome Sciences'])
      service.update_affiliations(obj)
      obj.reload
      first_translator = obj.translators.find { |person| person['index'] == [1] }
      expect(obj.translators.count).to eq 4
      expect(first_translator.attributes['affiliation']).to eq(['Carolina Center for Genome Sciences'])
    end

    it 'does not map affiliations that are still unmappable' do
      third_translator = obj.translators.find { |person| person['index'] == [3] }
      original_person_hash = third_translator.attributes
      expect(service.map_person_attributes(original_person_hash)).to eq(updated_translator_3_hash)
    end

    it 'keeps the original affiliation if it is mappable' do
      first_translator = obj.translators.find { |person| person['index'] == [1] }
      original_person_hash = first_translator.attributes
      expect(service.map_person_attributes(original_person_hash)).to eq(updated_translator_1_hash)
    end
  end
end
