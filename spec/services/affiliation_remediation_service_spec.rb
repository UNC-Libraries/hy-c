require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe AffiliationRemediationService do
  let(:service) { described_class.new(unmappable_affiliations_path) }
  let(:unmappable_affiliations_path) { File.join(fixture_path, 'files', 'short_unmappable_affiliations.csv') }
  let(:uncontrolled_affiliation_one) { 'University of North Carolina at Chapel Hill. Library' }
  let(:mapped_affiliation_one) { 'University of North Carolina at Chapel Hill. University Libraries' }
  let(:uncontrolled_affiliation_two) { 'Department of Economics and Curriculum for the Environment and Ecology; University of North Carolina at Chapel Hill' }
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
                                      affiliation: uncontrolled_affiliation_one,
                                      index: 1 },
                             '1' => { name: 'creator_2',
                                      affiliation: uncontrolled_affiliation_two,
                                      index: 2 } }
    )
  end
  let(:work_with_people) do
    General.create(title: ['New General Work with people'],
                   translators_attributes: { '0' => { name: 'translator_1',
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
                                                      index: 4 } },
                   creators_attributes: { '0' => { name: 'creator_1',
                                                   affiliation: 'Carolina Center for Genome Sciences',
                                                   index: 1 } })
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
    expect(service.map_to_new_affiliation(uncontrolled_affiliation_one)).to eq(mapped_affiliation_one)
    expect(service.map_to_new_affiliation(uncontrolled_affiliation_two)).to eq(mapped_affiliation_two)
  end

  it 'can determine if an affiliation is unmappable' do
    expect(service.mappable_affiliation?(uncontrolled_affiliation_one)).to eq false
    expect(service.mappable_affiliation?(mapped_affiliation_one)).to eq true
  end

  context 'with an empty string as the old affiliation' do
    let(:uncontrolled_affiliation_one) { '' }
    let(:updated_person_hash) do
      {
        'index' => [1],
        'name' => ['creator_1'],
        'orcid' => [],
        'affiliation' => [],
        'other_affiliation' => []
      }
    end

    it 'maps the empty string to an empty array' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      original_person_hash = first_creator.attributes
      expect(service.map_person_attributes(original_person_hash)).to eq(updated_person_hash)
    end
  end

  context 'with one affiliation that needs to be mapped and one empty one' do
    let(:article) do
      FactoryBot.create(
        :article,
        id: article_identifier,
        creators_attributes: { '0' => { name: 'creator_1',
                                        affiliation: uncontrolled_affiliation_one,
                                        index: 1 },
                               '1' => { name: 'creator_2',
                                        index: 2 } }
      )
    end
    let(:updated_second_creator_hash) do
      {
        'index' => [2],
        'name' => ['creator_2'],
        'orcid' => [],
        'affiliation' => [],
        'other_affiliation' => []
      }
    end

    it 'maps the attributes for both creators' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      original_first_creator_hash = first_creator.attributes
      expect(service.map_person_attributes(original_first_creator_hash)).to eq(updated_person_hash)
      second_creator = obj.creators.find { |person| person['index'] == [2] }
      original_second_creator_hash = second_creator.attributes
      expect(service.map_person_attributes(original_second_creator_hash)).to eq(updated_second_creator_hash)
    end

    it 'keeps both creators associated with the object' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([uncontrolled_affiliation_one])
      second_creator = obj.creators.find { |person| person['index'] == [2] }
      expect(second_creator.attributes['affiliation']).to eq([])
      service.update_affiliations(obj)
      obj.reload
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([mapped_affiliation_one])
      second_creator = obj.creators.find { |person| person['index'] == [2] }
      expect(second_creator.attributes['affiliation']).to eq([])
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

  context 'with an affiliation that needs to be moved to "other_affiliation"' do
    let(:uncontrolled_affiliation_one) { 'Colorado School of Public Health' }
    let(:updated_person_hash) do
      {
        'index' => [1],
        'name' => ['creator_1'],
        'orcid' => [],
        'affiliation' => [],
        'other_affiliation' => [uncontrolled_affiliation_one]
      }
    end

    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      article
    end

    it 'moves non-UNC affiliations to "other_affiliation"' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      original_person_hash = first_creator.attributes
      expect(service.map_person_attributes(original_person_hash)).to eq(updated_person_hash)
    end

    it 'can update the creator affiliations' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([uncontrolled_affiliation_one])
      expect(first_creator.attributes['other_affiliation']).to eq([])
      service.update_affiliations(obj)
      obj.reload
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(first_creator.attributes['affiliation']).to eq([])
      expect(first_creator.attributes['other_affiliation']).to eq([uncontrolled_affiliation_one])
    end
  end

  context 'with multiple affiliations' do
    let(:uncontrolled_affiliation_one) { 'Departmentrof Chemistry and Neuroscience Center University of North Carolina at Chapel Hill Chapel Hill, NC 27599-3290' }
    let(:mapped_affiliation_one) { ['UNC Neuroscience Center', 'Department of Chemistry'] }

    it 'can map from an unmappable affiliation to a mappable affiliation' do
      expect(service.map_to_new_affiliation(uncontrolled_affiliation_one)).to eq(mapped_affiliation_one)
    end

    context 'with an article' do
      before do
        ActiveFedora::Cleaner.clean!
        Blacklight.default_index.connection.delete_by_query('*:*')
        Blacklight.default_index.connection.commit
        article
      end

      it 'can update the creator affiliations' do
        first_creator = obj.creators.find { |person| person['index'] == [1] }
        expect(first_creator.attributes['affiliation']).to eq([uncontrolled_affiliation_one])
        service.update_affiliations(obj)
        obj.reload
        first_creator = obj.creators.find { |person| person['index'] == [1] }
        expect(first_creator.attributes['affiliation']).to eq(mapped_affiliation_one)
      end
    end
  end

  context 'with two creators with affiliations that need to be mapped' do
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
      expect(first_creator.attributes['affiliation']).to eq([uncontrolled_affiliation_one])
    end

    it 'limits calls to the DepartmentService' do
      allow(DepartmentsService).to receive(:label)
      service.update_affiliations(obj)
      expect(DepartmentsService).to have_received(:label).with(uncontrolled_affiliation_one).twice
    end

    it 'can update the creator affiliations' do
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      second_creator = obj.creators.find { |person| person['index'] == [2] }
      expect(first_creator.attributes['affiliation']).to eq([uncontrolled_affiliation_one])
      expect(second_creator.attributes['affiliation']).to eq([uncontrolled_affiliation_two])
      service.update_affiliations(obj)
      obj.reload
      first_creator = obj.creators.find { |person| person['index'] == [1] }
      second_creator = obj.creators.find { |person| person['index'] == [2] }
      expect(first_creator.attributes['affiliation']).to eq([mapped_affiliation_one])
      expect(second_creator.attributes['affiliation']).to eq([mapped_affiliation_two])
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

  context 'with a general work with a different type of people object' do
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

    it 'recognizes that the creators do not need to be updated' do
      expect(service.needs_updated_people?(obj, :creators)).to eq false
    end

    it 'recognizes that the translators do need to be updated' do
      expect(service.needs_updated_people?(obj, :translators)).to eq true
    end

    it 'only updates the translator, not the creator' do
      allow(obj).to receive(:save!)
      before_first_translator = obj.translators.find { |person| person['index'] == [1] }
      before_first_creator = obj.creators.find { |person| person['index'] == [1] }
      service.update_affiliations(obj)
      obj.reload
      after_first_translator = obj.translators.find { |person| person['index'] == [1] }
      after_first_creator = obj.creators.find { |person| person['index'] == [1] }
      expect(before_first_translator).not_to eq(after_first_translator)
      expect(before_first_creator).to eq(after_first_creator)
      # When it only updates the translators it still saves twice - once for blanking out the translators, once for
      # entering the new values
      expect(obj).to have_received(:save!).twice
    end
  end
end
