# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/lib/active-fedora/rdf/indexing_service_override.rb')

RSpec.describe ActiveFedora::RDF::IndexingService do
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
    let(:indexer) { described_class.new(work, work.class.index_config) }
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
    context 'when adding people objects' do
      let(:indexer) { described_class.new(work, work.class.index_config) }
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
                                          index: 1 } },
          advisors_attributes: { '0' => { name: 'advisor_1',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          index: 1 } },
          contributors_attributes: { '0' => { name: 'contributor_1',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          index: 1 } },
          date_created: '2022-01-01')

      end
      let(:translator1_string) { "index:1||translator_1||Affiliation: School of Medicine, Carolina Center for Genome Sciences" }
      let(:translator2_string) { "index:2||translator_2||Affiliation: College of Arts and Sciences, Department of Chemistry" }
      subject(:solr_doc) do
        indexer.generate_solr_document
      end

      it 'includes person attributes' do
        expect(solr_doc['translator_display_tesim']).to include(translator1_string, translator2_string)
        expect(solr_doc['creator_display_tesim']).to eq ["index:1||creator_1||Affiliation: School of Medicine, Carolina Center for Genome Sciences"]
        expect(solr_doc['person_label_tesim']).to include("advisor_1", "translator_2", "translator_1", "creator_1", "contributor_1")
        expect(solr_doc['affiliation_label_tesim']).to include("Department of Chemistry", "Carolina Center for Genome Sciences")
        expect(solr_doc['affiliation_label_sim']).to include("Department of Chemistry", "Carolina Center for Genome Sciences")
        expect(solr_doc['creator_label_tesim']).to eq ["creator_1"]
        expect(solr_doc['creator_label_sim']).to eq ["creator_1"]
        expect(solr_doc['contributor_label_tesim']).to eq ["contributor_1"]
        expect(solr_doc['contributor_label_sim']).to eq ["contributor_1"]
        expect(solr_doc['advisor_label_tesim']).to eq ["advisor_1"]
        expect(solr_doc['advisor_label_sim']).to eq ["advisor_1"]
      end
    end

    context 'with date_created set' do
      let(:date_index_config) do
        {}.tap do |index_config|
          index_config[:date_created] = ActiveFedora::Indexing::Map::IndexObject.new(:date_created) do |index|
            index.as :sortable, :displayable, :stored_searchable
            index.type :text
          end
          index_config[:title] = ActiveFedora::Indexing::Map::IndexObject.new(:title) do |index|
            index.as :stored_searchable, :sortable
            index.type :text
          end
        end
      end
      let(:indexer) { described_class.new(work, date_index_config) }

      context 'when adding Date object' do
        let(:work) do
          General.create(
            title: ['New General Date Work'],
            date_created: Date.new(2022, 10, 1))
        end
        subject(:solr_doc) do
          indexer.generate_solr_document
        end
        it 'converts to edtf date date correctly when date_created is Date object' do
          expect(solr_doc.fetch('date_created_tesim')).to eq ['October 1, 2022']
        end
      end

      context 'when adding date string' do
        let(:work) do
          General.create(
            title: ['New General Work'],
            date_created: '2022-10-01')
        end
        subject(:solr_doc) do
          indexer.generate_solr_document
        end
        it 'converts to edtf date correctly when date_created is date string' do
          expect(solr_doc.fetch('date_created_tesim')).to eq ['October 1, 2022']
        end
      end
    end
  end
end
