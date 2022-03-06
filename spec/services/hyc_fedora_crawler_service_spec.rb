require 'rails_helper'

RSpec.describe HycFedoraCrawlerService do
  let(:type_of_person) { :creators }

  let(:work_with_people) do
    General.create(title: ['New General Work with people'],
                   "#{type_of_person}_attributes".to_sym => { '0' => { name: "#{type_of_person}_1",
                                                                       affiliation: 'Carolina Center for Genome Sciences',
                                                                       index: 1 },
                                                              '1' => { name: "#{type_of_person}_2",
                                                                       affiliation: 'Department of Chemistry',
                                                                       index: 2 } })
  end

  let(:work_without_people) { FactoryBot.create(:admin_set) }

  before do
    work_with_people
  end

  it 'knows what fields are person fields' do
    expect(described_class.person_fields).to match_array([:advisors, :arrangers, :composers, :contributors, :creators,
                                                          :project_directors, :researchers, :reviewers, :translators])
  end

  it 'knows whether an object responds to the person fields' do
    expect(described_class.has_person_field?(work_without_people)).to eq false
    expect(described_class.has_person_field?(work_with_people)).to eq true
  end

  context 'with creators' do
    let(:type_of_person) { :creators }

    it 'can crawl over all the objects in Fedora and return pairs of ids and affiliations' do
      yielded = []
      described_class.crawl_for_affiliations do |document_id, affiliations|
        yielded << { id: document_id, affiliations: affiliations }
      end
      target_hash = yielded.find { |x| x[:id] == work_with_people.id }
      expect(target_hash[:affiliations]).to match_array([['Department of Chemistry'], ['Carolina Center for Genome Sciences']])
    end

    it 'can return the affiliations connected to an object' do
      expect(described_class.person_affiliations_by_type(work_with_people, :creators)).to match_array([['Department of Chemistry'], ['Carolina Center for Genome Sciences']])
    end
  end

  context 'with reviewers' do
    let(:type_of_person) { :reviewers }

    it 'can crawl over all the objects in Fedora and return pairs of ids and affiliations' do
      yielded = []
      described_class.crawl_for_affiliations do |document_id, affiliations|
        yielded << { id: document_id, affiliations: affiliations }
      end
      target_hash = yielded.find { |x| x[:id] == work_with_people.id }
      expect(target_hash[:affiliations]).to match_array([['Department of Chemistry'], ['Carolina Center for Genome Sciences']])
    end

    it 'can return the affiliations connected to an object' do
      expect(described_class.person_affiliations_by_type(work_with_people, type_of_person)).to match_array([['Department of Chemistry'], ['Carolina Center for Genome Sciences']])
    end
  end
end
