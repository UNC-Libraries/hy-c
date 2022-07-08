require 'rails_helper'
require 'active_fedora/base'
require 'fileutils'

RSpec.describe Tasks::SolrMigrationService do
  let(:service) { described_class.new }

  let(:output_dir) { Dir.mktmpdir }

  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end

  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end

  before do
    # Reset contents of solr
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
    admin_set
    permission_template
    workflow
    workflow_state
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    # return the FactoryBot admin_set when searching for admin set from config
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
  end

  after do
    FileUtils.remove_entry(output_dir)
  end

  context 'with multiple works populated' do
    let(:work1) do
      HonorsThesis.create(title: ['Honors thesis Work 1'],
                          visibility: 'open',
                          admin_set_id: admin_set.id,
                          doi: 'https://doi.org/10.5077/test-doi')
    end

    let(:work2) do
      Article.create(title: ['Article Work 2'],
                     date_issued: '2020',
                     resource_type: ['Article'],
                     funder: ['a funder'],
                     subject: ['subject1', 'subject2'],
                     abstract: ['a description'],
                     extent: ['some extent'],
                     language_label: ['English'],
                     rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/')
    end

    before do
      work1.save!
      work2.save!
    end

    it 'Lists ids and reindexes them' do
      initial_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(initial_records['response']['numFound']).to eq 7

      list_path = service.list_object_ids(output_dir, nil)

      # Empty out solr so we can repopulate it
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit

      emptied_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(emptied_records['response']['numFound']).to eq 0

      service.reindex(list_path, false)
      reindexed_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(reindexed_records['response']['numFound']).to eq 7
      expect_results_match(initial_records, reindexed_records)
    end

    it 'List ids with timestamp' do
      initial_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      all_ids = initial_records['response']['docs'].map { |record| record['id'] }
      expect(all_ids.length).to eq 7

      # In the distant future
      list_path = service.list_object_ids(output_dir, '3000-01-01T00:00:00Z')
      id_list = File.readlines(list_path, chomp: true).sort
      expect(id_list).to be_empty

      # In the past
      list_path = service.list_object_ids(output_dir, '2000-01-01T00:00:00Z')
      id_list = File.readlines(list_path, chomp: true).sort
      expect(id_list).to eq all_ids

      # Formatted like filename
      list_path = service.list_object_ids(output_dir, '2000-01-01T00_00_00Z')
      id_list = File.readlines(list_path, chomp: true).sort
      expect(id_list).to eq all_ids
    end

    it 'List ids with invalid timestamp fails' do
      expect { service.list_object_ids(output_dir, 'one hundred percent not a date') }.to raise_error(ArgumentError)
    end

    it 'Resume partial migration' do
      initial_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(initial_records['response']['numFound']).to eq 7

      list_path = service.list_object_ids(output_dir, nil)
      progress_log = service.progress_log_path(list_path)

      # List half the ids as done
      id_list = File.readlines(list_path, chomp: true)
      split_ids = id_list.each_slice(4).to_a
      File.open(progress_log, 'w') { |file| file.write(split_ids[0].join("\n").to_s) }

      # Empty out solr so we can repopulate it
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit

      # Cannot resume with clean index flag provided
      expect { service.reindex(list_path, true) }.to raise_error(ArgumentError)

      service.reindex(list_path, false)
      reindexed_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(reindexed_records['response']['numFound']).to eq 3
      # Reindexed ids should match the ids not in the progress log
      reindexed_ids = reindexed_records['response']['docs'].map { |record| record['id'] }
      expect(reindexed_ids.sort).to eq split_ids[1].sort
    end

    it 'Index with invalid id is skipped' do
      # Sort by created time in order to delete a consistent object across runs
      initial_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(initial_records['response']['numFound']).to eq 7

      list_path = service.list_object_ids(output_dir, nil)

      # Delete an object from fedora
      target_records = ActiveFedora::SolrService.get('has_model_ssim:HonorsThesis', rows: 1, sort: 'id ASC')
      ActiveFedora::Base.find(target_records['response']['docs'][0]['id']).delete

      # Using a clean reindex to reset the index before repopulation
      service.reindex(list_path, true)
      reindexed_records = ActiveFedora::SolrService.get('*:*', rows: 100, sort: 'id ASC')
      expect(reindexed_records['response']['numFound']).to eq 6
    end

    it 'Index with invalid input file' do
      list_path = service.list_object_ids(output_dir, nil)
      # Delete the list file so that it won't be found when running reindexng
      FileUtils.rm(list_path)

      allow(Rails.logger).to receive(:error)
      service.reindex(list_path, false)

      expect(Rails.logger).to have_received(:error).with('Execution interrupted by unexpected error')
    end

    def expect_results_match(results1, results2)
      docs1 = results1['response']['docs']
      docs2 = results2['response']['docs']
      docs1.each_with_index do |record1, index|
        record2 = docs2[index]
        record1.each do |key, value|
          next if ['timestamp', '_version_'].include?(key)

          expect(value).to eq(record2[key]), "Expected #{key} to have value #{value} but was #{record2[key]}"
        end
        expect(record1.length).to eq record2.length
      end
    end
  end
end
