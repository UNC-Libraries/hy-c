# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/hyrax/downloads_controller_override.rb')

RSpec.describe WorkUtilsHelper, type: :module do
  let(:fileset_ids) { ['file-set-id-0', 'file-set-id-1', 'file-set-id-2', 'file-set-id-3'] }
  let(:admin_set_name) { 'Open_Access_Articles_and_Book_Chapters' }

  let(:mock_records) { [[{
    'has_model_ssim' => ['Article'],
    'id' =>  '1z40m031g',
    'title_tesim' => ['Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response'],
    'admin_set_tesim' => ['Open_Access_Articles_and_Book_Chapters'],
    'doi_tesim' => ['test-doi']
  }],
  [{
    'has_model_ssim' => ['Article'],
    'id' =>  '1z40m031g-2',
    'title_tesim' => ['Placeholder Title'],
    'admin_set_tesim' => [],
    'doi_tesim' => ['test-doi']
  }],
  [{
    'has_model_ssim' => ['Article'],
    'id' =>  '1z40m031g',
    'title_tesim' => ['Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response'],
    'admin_set_tesim' => ['Open_Access_Articles_and_Book_Chapters'],
    'file_set_ids_ssim' => ['file-set-id-0', 'file-set-id-1', 'file-set-id-2', 'file-set-id-3'],
    'doi_tesim' => ['test-doi']
  }
  ]
  ]
  }

  let(:mock_admin_set) { [{
    'has_model_ssim' => ['AdminSet'],
    'id' => 'h128zk07m',
    'title_tesim' => ['Open_Access_Articles_and_Book_Chapters']}
  ]
  }

  let(:expected_work_data) { [{
     work_id: '1z40m031g',
     work_type: 'Article',
     title: 'Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response',
     admin_set_id: 'h128zk07m',
     admin_set_name: 'Open_Access_Articles_and_Book_Chapters'
  },
  {
     work_id: '1z40m031g',
     work_type: 'Article',
     title: 'Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response',
     admin_set_id: 'h128zk07m',
     admin_set_name: 'Open_Access_Articles_and_Book_Chapters',
     file_set_names: ['title_0', 'title_1', 'title_2', 'title_3']
  }
  ]
  }

  describe '#fetch_work_data_by_fileset_id' do
    it 'fetches the work data correctly' do
      allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_ids[0]}", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_ids[0])
      expect(result).to eq(expected_work_data[0])
    end

    it 'logs appropriate messages for missing values' do
        # Mock the solr response to simulate a work with missing values, if it somehow makes it past the initial nil check
      allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_ids[0]}", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_ids[0])
      expect(Rails.logger).to have_received(:warn).with("No work found associated with fileset id: #{fileset_ids[0]}")
      expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with fileset id: #{fileset_ids[0]} has no admin set name.")
      expect(result[:work_id]).to be_nil
      expect(result[:work_type]).to be_nil
      expect(result[:title]).to be_nil
      expect(result[:admin_set_id]).to be_nil
    end

    context 'when admin set is not found' do
      it 'logs an appropriate message if the work doesnt have an admin set title' do
        # Using the mock record without an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_ids[1]}", rows: 1).and_return('response' => { 'docs' => mock_records[1] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_ids[1])
        expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with fileset id: #{fileset_ids[1]} has no admin set name.")
        expect(result[:admin_set_id]).to be_nil
      end

      it 'logs an appropriate message if the query for an admin set returns nothing' do
        # Using the mock record with an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_ids[1]}", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
        allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => [{}] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_ids[1])
        expect(Rails.logger).to have_received(:warn).with("No admin set found with title_tesim: #{admin_set_name}.")
        expect(result[:admin_set_id]).to be_nil
      end
    end
  end

  describe '#fetch_work_data_by_id' do
    it 'fetches the work data correctly' do
      mock_record_id = mock_records[0][0]['id']
      allow(ActiveFedora::SolrService).to receive(:get).with("id:#{mock_record_id}", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      result = WorkUtilsHelper.fetch_work_data_by_id(mock_record_id)
      expect(result).to eq(expected_work_data[0])
    end

    it 'logs appropriate messages for missing values' do
        # Mock the solr response to simulate a work with missing values, if it somehow makes it past the initial nil check
      mock_record_id = mock_records[0][0]['id']
      allow(ActiveFedora::SolrService).to receive(:get).with("id:#{mock_record_id}", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_id(mock_record_id)
      expect(Rails.logger).to have_received(:warn).with("No work found associated with work id: #{mock_record_id}")
      expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with id: #{mock_record_id} has no admin set name.")
      expect(result[:work_id]).to be_nil
      expect(result[:work_type]).to be_nil
      expect(result[:title]).to be_nil
      expect(result[:admin_set_id]).to be_nil
    end

    context 'when admin set is not found' do
      it 'logs an appropriate message if the work doesnt have an admin set title' do
        mock_record_id = mock_records[1][0]['id']
        # Using the mock record without an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("id:#{mock_record_id}", rows: 1).and_return('response' => { 'docs' => mock_records[1] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_id(mock_record_id)
        expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with id: #{mock_record_id} has no admin set name.")
        expect(result[:admin_set_id]).to be_nil
      end

      it 'logs an appropriate message if the query for an admin set returns nothing' do
        mock_record_id = mock_records[1][0]['id']
        # Using the mock record with an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("id:#{mock_record_id}", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
        allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => [{}] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_id(mock_record_id)
        expect(Rails.logger).to have_received(:warn).with("No admin set found with title_tesim: #{admin_set_name}.")
        expect(result[:admin_set_id]).to be_nil
      end
    end
  end

  describe '#fetch_work_data_by_alternate_identifier' do
    let (:mock_pmid) { '12345678' }
    it 'fetches the work data correctly' do
      allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\"", rows: 1).and_return('response' => { 'docs' => mock_records[2] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      (0..3).each do |i|
        allow(ActiveFedora::SolrService).to receive(:get).with("id:#{fileset_ids[i]}", rows: 1).and_return('response' => { 'docs' => [{'title_tesim' => ["title_#{i}"]}] })
      end
      result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
      expect(result).to eq(expected_work_data[1])
    end

    it 'logs appropriate messages for missing values' do
        # Mock the solr response to simulate a work with missing values, if it somehow makes it past the initial nil check
      allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\"", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
      expect(Rails.logger).to have_received(:warn).with("No work found associated with alternate identifier: #{mock_pmid}")
      expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with id: #{mock_pmid} has no admin set name.")
      expect(result[:work_id]).to be_nil
      expect(result[:work_type]).to be_nil
      expect(result[:title]).to be_nil
      expect(result[:admin_set_id]).to be_nil
      expect(result[:file_set_names]).to be_empty
    end

    it 'logs a message if a fileset cannot be found with the id' do
      allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\"", rows: 1).and_return('response' => { 'docs' => mock_records[2] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      (0..2).each do |i|
        allow(ActiveFedora::SolrService).to receive(:get).with("id:#{fileset_ids[i]}", rows: 1).and_return('response' => { 'docs' => [{'title_tesim' => ["title_#{i}"]}] })
      end
      allow(ActiveFedora::SolrService).to receive(:get).with("id:#{fileset_ids[3]}", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
      expect(Rails.logger).to have_received(:warn).with('No Fileset found for ID: file-set-id-3')
      expect(result[:file_set_names]).to eq(['title_0', 'title_1', 'title_2'])
    end



    context 'when admin set is not found' do
      it 'logs an appropriate message if the work doesnt have an admin set title' do
          # Using the mock record without an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\"", rows: 1).and_return('response' => { 'docs' => mock_records[1] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
        expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with id: #{mock_pmid} has no admin set name.")
        expect(Rails.logger).to have_received(:warn).with('No Fileset IDs provided.')
        expect(result[:admin_set_id]).to be_nil
      end

      it 'logs an appropriate message if the query for an admin set returns nothing' do
        # Using the mock record with an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\"", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
        allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => [{}] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
        expect(Rails.logger).to have_received(:warn).with("No admin set found with title_tesim: #{admin_set_name}.")
        expect(Rails.logger).to have_received(:warn).with('No Fileset IDs provided.')
        expect(result[:admin_set_id]).to be_nil
      end
    end
  end

  describe '#fetch_work_data_by_doi' do
    it 'fetches the work data correctly' do
      mock_record_doi = mock_records[0][0]['doi_tesim'].first
      allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{mock_record_doi}\"", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      result = WorkUtilsHelper.fetch_work_data_by_doi(mock_record_doi)
      expect(result).to eq(expected_work_data[0])
    end

    it 'logs appropriate messages for missing values' do
      # Mock the solr response to simulate a work with missing values, if it somehow makes it past the initial nil check
      mock_record_doi = mock_records[0][0]['doi_tesim'].first
      allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{mock_record_doi}\"", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_doi(mock_record_doi)
      expect(Rails.logger).to have_received(:warn).with("No work found associated with doi: #{mock_record_doi}")
      expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with doi: #{mock_record_doi} has no admin set name.")
      expect(result[:work_id]).to be_nil
      expect(result[:work_type]).to be_nil
      expect(result[:title]).to be_nil
      expect(result[:admin_set_id]).to be_nil
    end

    context 'when admin set is not found' do
      it 'logs an appropriate message if the work doesnt have an admin set title' do
        mock_record_doi = mock_records[0][0]['doi_tesim'].first
        # Using the mock record without an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{mock_record_doi}\"", rows: 1).and_return('response' => { 'docs' => mock_records[1] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_doi(mock_record_doi)
        expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with doi: #{mock_record_doi} has no admin set name.")
        expect(result[:admin_set_id]).to be_nil
      end

      it 'logs an appropriate message if the query for an admin set returns nothing' do
        mock_record_doi = mock_records[0][0]['doi_tesim'].first
        # Using the mock record with an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{mock_record_doi}\"", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
        allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => [{}] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_doi(mock_record_doi)
        expect(Rails.logger).to have_received(:warn).with("No admin set found with title_tesim: #{admin_set_name}.")
        expect(result[:admin_set_id]).to be_nil
      end
    end
  end
end
