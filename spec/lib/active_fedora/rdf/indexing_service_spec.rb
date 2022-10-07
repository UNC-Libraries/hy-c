# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/lib/active-fedora/rdf/indexing_service_override.rb')

RSpec.describe ActiveFedora::RDF::IndexingService do
  let(:indexer) { described_class.new(work) }
  # test that class attribute is populated from override
  describe 'class variable creation' do
    let(:work) { ActiveFedora::Base.new }
    let(:expected) { %w[advisors arrangers composers contributors creators project_directors
      researchers reviewers translators]
    }
    it { expect(described_class.person_fields).to be_equivalent_to(expected) }
  end

  describe '#new' do
    let(:work) { ActiveFedora::Base.new }
    it 'creates label variables' do
      expect(indexer.instance_variable_get(:@person_label)).not_to be_nil
      expect(indexer.instance_variable_get(:@creator_label)).not_to be_nil
      expect(indexer.instance_variable_get(:@advisor_label)).not_to be_nil
      expect(indexer.instance_variable_get(:@contributor_label)).not_to be_nil
      expect(indexer.instance_variable_get(:@orcid_label)).not_to be_nil
      expect(indexer.instance_variable_get(:@affiliation_label)).not_to be_nil
      expect(indexer.instance_variable_get(:@other_affiliation_label)).not_to be_nil
    end
  end

  describe '#generate_solr_document' do
    context 'when adding assertions' do
      let(:work) do
        General.create(
          title: ['New General Work with people'],
          translators_attributes: { '0' => { name: 'translator_1',
                                              affiliation: 'Carolina Center for Genome Sciences',
                                              index: 1 },
                                     '1' => { name: 'translator_2',
                                              affiliation: 'Department of Chemistry',
                                              index: 2 } },
          creators_attributes: { '0' => { name: 'creator_1',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          index: 1 } })

      end
      let(:expected_translator_display) {[
        "index:2||translator_2||Affiliation: College of Arts and Sciences, Department of Chemistry",
        "index:1||translator_1||Affiliation: School of Medicine, Carolina Center for Genome Sciences"
      ]}
      subject(:solr_doc) do
        indexer.generate_solr_document
      end

      it 'includes person attributes' do
        expect(solr_doc['translator_display_tesim']).to eq expected_translator_display
        expect(solr_doc['creator_display_tesim']).to eq ["index:1||creator_1||Affiliation: School of Medicine, Carolina Center for Genome Sciences"]
        expect(solr_doc['person_label_tesim']).to eq ["translator_2", "translator_1", "creator_1"]
        expect(solr_doc['affiliation_label_tesim']).to eq ["Department of Chemistry", "Carolina Center for Genome Sciences"]
        expect(solr_doc['affiliation_label_sim']).to eq ["Department of Chemistry", "Carolina Center for Genome Sciences"]
        expect(solr_doc['creator_label_tesim']).to eq ["creator_1"]
        expect(solr_doc['creator_label_sim']).to eq ["creator_1"]
      end

      it 'converts edtf date correctly when set with Date object' do
        work.date_created = Date.new(2022, 10, 1)
        expect(solr_doc.fetch('date_created_tesim')).to eq ['October 1, 2022']
        expect(solr_doc.fetch('date_created_edtf_tesim')).to eq ['2022-10-01']
      end
    end
  end
end
