# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HycCrawlerService do
  let(:type_of_person) { :creators }
  let(:yielded) do
    yielded = []
    described_class.crawl_for_affiliations do |document_id, url, affiliations|
      yielded << { id: document_id, url: url, affiliations: affiliations }
    end
    yielded
  end
  let(:expected_affiliations_array) { ['Department of Chemistry', 'Carolina Center for Genome Sciences', 'Unmappable affiliation 1', 'Unmappable affiliation 2'] }

  let(:target_hash) { yielded.find { |x| x[:id] == work_with_people.id } }

  let(:work_with_people) do
    General.create(:title => ['New General Work with people'],
                   "#{type_of_person}_attributes".to_sym => { '0' => { name: "#{type_of_person}_1",
                                                                       affiliation: 'Carolina Center for Genome Sciences',
                                                                       index: 1 },
                                                              '1' => { name: "#{type_of_person}_2",
                                                                       affiliation: 'Department of Chemistry',
                                                                       index: 2 },
                                                              '2' => { name: "#{type_of_person}_3",
                                                                       affiliation: 'Unmappable affiliation 1',
                                                                       index: 3 },
                                                              '3' => { name: "#{type_of_person}_4",
                                                                       affiliation: 'Unmappable affiliation 2',
                                                                       index: 4 } })
  end

  let(:work_without_people) { FactoryBot.create(:admin_set) }

  before do
    work_with_people
  end

  it 'knows what fields are person fields' do
    expect(described_class.person_fields).to match_array([:advisors, :arrangers, :composers, :contributors, :creators,
                                                          :project_directors, :researchers, :reviewers, :translators])
  end

  context 'without affiliations' do
    let(:work_with_people) do
      General.create(:title => ['New General Work with people'],
                     "#{type_of_person}_attributes".to_sym => { '0' => { name: "#{type_of_person}_1",
                                                                         index: 1 },
                                                                '1' => { name: "#{type_of_person}_2",
                                                                         index: 2 } })
    end

    it 'does not yield anything for the object' do
      expect(target_hash).to eq nil
    end
  end

  context 'with empty string affiliations' do
    let(:work_with_people) do
      General.create(:title => ['New General Work with people'],
                     "#{type_of_person}_attributes".to_sym => { '0' => { name: "#{type_of_person}_1",
                                                                         affiliation: [''],
                                                                         index: 1 },
                                                                '1' => { name: "#{type_of_person}_2",
                                                                         affiliation: [''],
                                                                         index: 2 } })
    end

    it 'does not yield anything for the object' do
      expect(described_class.person_affiliations_by_type(work_with_people, type_of_person)).to eq([])
      expect(work_with_people.creators.first.attributes['affiliation']).to eq ['']
      expect(target_hash).to eq nil
    end
  end

  context 'creating a csv' do
    let(:csv_path) { "#{ENV['DATA_STORAGE']}/reports/unmappable_affiliations.csv" }
    let(:work_with_only_mappable_affils) do
      General.create(:title => ['New General Work with people'],
                     "#{type_of_person}_attributes".to_sym => { '0' => { name: "#{type_of_person}_1",
                                                                         affiliation: 'Carolina Center for Genome Sciences',
                                                                         index: 1 },
                                                                '1' => { name: "#{type_of_person}_2",
                                                                         affiliation: 'Department of Chemistry',
                                                                         index: 2 } })
    end
    before do
      work_with_only_mappable_affils
    end
    after do
      FileUtils.remove_entry(csv_path) if File.exist?(csv_path)
    end
    it 'writes unmappable affiliations to a csv' do
      expect(File.exist?(csv_path)).to eq false
      described_class.create_csv_of_unmappable_affiliations
      expect(File.exist?(csv_path)).to eq true
    end

    describe 'turning the csv back into ruby objects' do
      before do
        described_class.create_csv_of_unmappable_affiliations
      end

      it 'is a parseable csv with headers' do
        csv = CSV.parse(File.read(csv_path), headers: true)

        expect(csv.headers).to eq(['object_id', 'url', 'affiliations'])
        target_row = csv.find { |row| row['object_id'] == work_with_people.id }.to_h

        expect(target_row['affiliations']).to eq('Unmappable affiliation 1 || Unmappable affiliation 2')
        row_without_unmappable_affiliations = csv.find { |row| row['object_id'] == work_with_only_mappable_affils.id }
        expect(row_without_unmappable_affiliations).to be nil
      end

      it 'can be turned back into ruby objects' do
        target_row = 'Unmappable affiliation 1 || Unmappable affiliation 2'
        expect(target_row.split(' || ')).to match_array(['Unmappable affiliation 1', 'Unmappable affiliation 2'])
      end
    end
  end

  context 'with creators' do
    let(:type_of_person) { :creators }

    it 'can crawl over all the objects in Fedora and return pairs of ids, urls, and affiliations' do
      expect(target_hash[:affiliations]).to match_array(expected_affiliations_array)
      expect(target_hash[:url]).to eq("#{ENV['HYRAX_HOST']}/concern/generals/#{work_with_people.id}")
    end

    it 'can return the affiliations connected to an object' do
      expect(described_class.person_affiliations_by_type(work_with_people, :creators)).to match_array(expected_affiliations_array)
    end

    it 'can return only the affiliations that are unmappable' do
      expect(described_class.unmappable_affiliations(expected_affiliations_array)).to match_array(['Unmappable affiliation 1', 'Unmappable affiliation 2'])
    end
  end

  context 'with reviewers' do
    let(:type_of_person) { :reviewers }

    it 'can crawl over all the objects in Fedora and return pairs of ids and affiliations' do
      expect(target_hash[:affiliations]).to match_array(expected_affiliations_array)
    end

    it 'can return the affiliations connected to an object' do
      expect(described_class.person_affiliations_by_type(work_with_people, type_of_person)).to match_array(expected_affiliations_array)
    end
  end
end
