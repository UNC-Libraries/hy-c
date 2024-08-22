# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/hyrax/downloads_controller_override.rb')

RSpec.describe WorkUtilsHelper, type: :module do
  let(:fileset_id) { 'file-set-id' }
  let(:admin_set_name) { 'Open_Access_Articles_and_Book_Chapters' }
  let(:example_admin_set_id) { 'h128zk07m' }
  let(:example_work_id) { '1z40m031g' }

  let(:mock_record) { [{
    'has_model_ssim' => ['Article'],
    'id' =>  '1z40m031g',
    'title_tesim' => ['Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response'],
    'admin_set_tesim' => ['Open_Access_Articles_and_Book_Chapters']}
  ]
  }

  let(:mock_admin_set) { [{
    'has_model_ssim' => ['AdminSet'],
    'id' => 'h128zk07m',
    'title_tesim' => ['Open_Access_Articles_and_Book_Chapters']}
  ]
  }

  let(:expected_work_data) { {
     work_id: '1z40m031g',
     work_type: 'Article',
     title: 'Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response',
     admin_set_id: 'h128zk07m',
     admin_set_name: 'Open_Access_Articles_and_Book_Chapters'
  }
  }

  before do
    allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_id}", rows: 1).and_return('response' => { 'docs' => mock_record })
    allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name}", rows: 1).and_return('response' => { 'docs' => mock_admin_set })
  end

  describe '#fetch_work_data_by_fileset_id' do
    it 'fetches the work data correctly' do
      result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_id)
      expect(result).to eq(expected_work_data)
    end

    it 'properly substitutes Unknown for missing values' do
        # Mock the solr response to simulate a work with missing values, if it somehow makes it past the initial nil check
      allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_id}", rows: 1).and_return('response' => { 'docs' => [{ 'placeholder-key' =>  'placeholder-value' }] })
      allow(ActiveFedora::SolrService).to receive(:get).with('title_tesim:Unknown', rows: 1).and_return('response' => { 'docs' => [] })
      result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_id)
      expect(result[:work_id]).to eq('Unknown')
      expect(result[:work_type]).to eq('Unknown')
      expect(result[:title]).to eq('Unknown')
      expect(result[:admin_set_id]).to eq('Unknown')
    end

    context 'when no work is found' do
      before do
        allow(ActiveFedora::SolrService).to receive(:get).with("file_set_ids_ssim:#{fileset_id}", rows: 1).and_return('response' => { 'docs' => [] })
      end

      it 'raises an error if no work is found' do
        expect { WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_id) }.to raise_error(RuntimeError, "No work found for fileset id: #{fileset_id}")
      end
    end

    context 'when admin set is not found' do
      before do
        allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name}", rows: 1).and_return('response' => { 'docs' => [] })
      end

      it 'sets the admin_set_id to Unknown if admin set is not found' do
        result = WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_id)
        expect(result[:admin_set_id]).to eq('Unknown')
      end
    end
  end
end
