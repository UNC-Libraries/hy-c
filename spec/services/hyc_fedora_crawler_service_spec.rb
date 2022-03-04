require 'rails_helper'

RSpec.describe HycFedoraCrawlerService do
  let(:work_with_people) do
    General.create(title: ['New General Work with people'],
                   creators_attributes: { '0' => { name: 'creator',
                                                   affiliation: 'Carolina Center for Genome Sciences',
                                                   index: 1 },
                                          '1' => { name: 'creator2',
                                                   affiliation: 'Department of Chemistry',
                                                   index: 2 } })
  end

  before do
    work_with_people
  end

  it 'can crawl over all the objects in Fedora and return pairs of ids and affiliations' do
    yielded = []
    described_class.crawl_for_affiliations do |document_id, affiliations|
      yielded << { id: document_id, affiliations: affiliations }
    end
    target_hash = yielded.find { |x| x[:id] == work_with_people.id }
    expect(target_hash[:affiliations]).to match_array([['Department of Chemistry'], ['Carolina Center for Genome Sciences']])
  end
end
