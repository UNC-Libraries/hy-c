# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hydra/controller/download_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/hyrax/downloads_controller_override.rb')

RSpec.describe WorkUtilsHelper, type: :module do
  let(:fileset_ids) { ['file-set-id-0', 'file-set-id-1', 'file-set-id-2', 'file-set-id-3'] }
  let(:admin_set_name) { 'Open_Access_Articles_and_Book_Chapters' }
  let(:host) { 'http://cdr-example.lib.unc.edu' }

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
     admin_set_name: 'Open_Access_Articles_and_Book_Chapters',
     file_set_ids: nil
  },
  {
     work_id: '1z40m031g',
     work_type: 'Article',
     title: 'Key ethical issues discussed at CDC-sponsored international, regional meetings to explore cultural perspectives and contexts on pandemic influenza preparedness and response',
     admin_set_id: 'h128zk07m',
     admin_set_name: 'Open_Access_Articles_and_Book_Chapters',
     file_set_ids:  ['file-set-id-0', 'file-set-id-1', 'file-set-id-2', 'file-set-id-3']
  }
  ]
  }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('HYRAX_HOST').and_return(host)
  end

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
      expect(result).to be_nil
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

    context 'when fallback to identifier_tesim is used' do
      let(:raw_doi) { 'https://dx.doi.org/10.1016/j.psc.2025.01.001' }
      let(:normalized_doi) { '10.1016/j.psc.2025.01.001' }

      it 'uses identifier_tesim fallback when doi_tesim query returns no results' do
        # doi_tesim returns nothing
        allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{raw_doi}\"", rows: 1).and_return('response' => { 'docs' => [] })

        # fallback match succeeds
        fallback_query = "identifier_tesim:\"DOI: https://dx.doi.org/#{normalized_doi}\" NOT has_model_ssim:(\"FileSet\")"
        allow(ActiveFedora::SolrService).to receive(:get).with(fallback_query, rows: 1).and_return('response' => { 'docs' => mock_records[0] })

        allow(ActiveFedora::SolrService).to receive(:get).with(
          "title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",
          { 'df' => 'title_tesim', :rows => 1 }
        ).and_return('response' => { 'docs' => mock_admin_set })

        result = WorkUtilsHelper.fetch_work_data_by_doi(raw_doi)
        expect(result).to eq(expected_work_data[0])
      end

      it 'returns nil and logs if fallback also fails' do
        allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{raw_doi}\"", rows: 1).and_return('response' => { 'docs' => [] })

        fallback_query = "identifier_tesim:\"DOI: https://dx.doi.org/#{normalized_doi}\" NOT has_model_ssim:(\"FileSet\")"
        allow(ActiveFedora::SolrService).to receive(:get).with(fallback_query, rows: 1).and_return('response' => { 'docs' => [] })

        allow(Rails.logger).to receive(:warn)

        result = WorkUtilsHelper.fetch_work_data_by_doi(raw_doi)
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with("No work found associated with doi: #{raw_doi}")
      end

      it 'does not perform fallback if doi is unrecognizable' do
        bad_doi = 'not-a-doi'
        allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{bad_doi}\"", rows: 1).and_return('response' => { 'docs' => [] })
        allow(Rails.logger).to receive(:warn)

        # No identifier_tesim fallback should happen
        expect(ActiveFedora::SolrService).not_to receive(:get).with(/identifier_tesim:/, rows: 1)

        result = WorkUtilsHelper.fetch_work_data_by_doi(bad_doi)
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with("Identifier does not appear to be a valid DOI: #{bad_doi}. Ending search.")
      end
    end

    it 'matches raw DOI input against full DOI URL stored in identifier_tesim' do
      raw_doi = '10.1016/j.psc.2025.01.001'

      # doi_tesim has no match
      allow(ActiveFedora::SolrService).to receive(:get).with("doi_tesim:\"#{raw_doi}\"", rows: 1).and_return('response' => { 'docs' => [] })

      # identifier_tesim contains full URL
      identifier_doc = {
        'id' => 'work-123',
        'has_model_ssim' => ['GenericWork'],
        'title_tesim' => ['Some Work'],
        'identifier_tesim' => ['DOI: https://dx.doi.org/10.1016/j.psc.2025.01.001'],
        'file_set_ids_ssim' => ['fs1'],
        'admin_set_tesim' => ['Sample Admin Set']
      }

      admin_set_doc = {
        'id' => 'adminset-999',
        'title_tesim' => ['Sample Admin Set']
      }

      fallback_query = "identifier_tesim:\"DOI: https://dx.doi.org/#{raw_doi}\" NOT has_model_ssim:(\"FileSet\")"
      allow(ActiveFedora::SolrService).to receive(:get).with(fallback_query, rows: 1).and_return('response' => { 'docs' => [identifier_doc] })
      allow(ActiveFedora::SolrService).to receive(:get).with('title_tesim:Sample Admin Set AND has_model_ssim:("AdminSet")', { 'df' => 'title_tesim', :rows => 1 }).and_return('response' => { 'docs' => [admin_set_doc] })

      result = WorkUtilsHelper.fetch_work_data_by_doi(raw_doi)
      expect(result[:work_id]).to eq('work-123')
      expect(result[:admin_set_name]).to eq('Sample Admin Set')
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
      expect(result).to be_nil
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
      allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\" NOT has_model_ssim:(\"FileSet\")", rows: 1).and_return('response' => { 'docs' => mock_records[2] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      (0..3).each do |i|
        allow(ActiveFedora::SolrService).to receive(:get).with("id:#{fileset_ids[i]}", rows: 1).and_return('response' => { 'docs' => [{'title_tesim' => ["title_#{i}"]}] })
      end
      result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
      expect(result).to eq(expected_work_data[1])
    end

    it 'logs appropriate messages for missing values' do
        # Mock the solr response to simulate a work with missing values, if it somehow makes it past the initial nil check
      allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\" NOT has_model_ssim:(\"FileSet\")", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
      expect(Rails.logger).to have_received(:warn).with("No work found associated with alternate identifier: #{mock_pmid}")
      expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with id: #{mock_pmid} has no admin set name.")
      expect(result).to be_nil
    end

    it 'logs a message if a fileset cannot be found with the id' do
      allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\" NOT has_model_ssim:(\"FileSet\")", rows: 1).and_return('response' => { 'docs' => mock_records[2] })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_admin_set })
      (0..2).each do |i|
        allow(ActiveFedora::SolrService).to receive(:get).with("id:#{fileset_ids[i]}", rows: 1).and_return('response' => { 'docs' => [{'title_tesim' => ["title_#{i}"]}] })
      end
      allow(ActiveFedora::SolrService).to receive(:get).with("id:#{fileset_ids[3]}", rows: 1).and_return('response' => { 'docs' => [] })
      allow(Rails.logger).to receive(:warn)
      result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
      expect(result[:file_set_ids]).to eq(['file-set-id-0', 'file-set-id-1', 'file-set-id-2', 'file-set-id-3'])
    end



    context 'when admin set is not found' do
      it 'logs an appropriate message if the work doesnt have an admin set title' do
          # Using the mock record without an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\" NOT has_model_ssim:(\"FileSet\")", rows: 1).and_return('response' => { 'docs' => mock_records[1] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
        expect(Rails.logger).to have_received(:warn).with("Could not find an admin set, the work with id: #{mock_pmid} has no admin set name.")
        expect(result[:admin_set_id]).to be_nil
      end

      it 'logs an appropriate message if the query for an admin set returns nothing' do
        # Using the mock record with an admin set title
        allow(ActiveFedora::SolrService).to receive(:get).with("identifier_tesim:\"#{mock_pmid}\" NOT has_model_ssim:(\"FileSet\")", rows: 1).and_return('response' => { 'docs' => mock_records[0] })
        allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => [{}] })
        allow(Rails.logger).to receive(:warn)
        result = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(mock_pmid)
        expect(Rails.logger).to have_received(:warn).with("No admin set found with title_tesim: #{admin_set_name}.")
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
      expect(result).to be_nil
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

  describe '#get_permissions_attributes' do
    let(:admin_set) { AdminSet.new(id: Date.today.to_time.to_i.to_s, title: ['a test admin set']) }
    let(:permission_template) { Hyrax::PermissionTemplate.new(id: Date.today.to_time.to_i, source_id: admin_set.id) }
    let(:manager_group) { Role.new(id: Date.today.to_time.to_i, name: 'manager_group') }
    let(:viewer_group) { Role.new(id: Date.today.to_time.to_i, name: 'viewer_group') }
    let(:manager_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: manager_group.name, proxy_for_type: 'Hyrax::Group') }
    let(:viewer_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: viewer_group.name, proxy_for_type: 'Hyrax::Group') }
    let(:expected_result) do
      [
        { 'type' => 'group', 'name' => manager_group.name, 'access' => 'edit' },
        { 'type' => 'group', 'name' => viewer_group.name, 'access' => 'read' }
      ]
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: manager_group.name,
                                             access: 'manage')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: viewer_group.name,
                                             access: 'view')
    end

    it 'finds manager and viewer groups for an admin set' do
      expect(described_class.get_permissions_attributes(admin_set.id)).to match_array expected_result
    end
  end

  describe '#generate_cdr_url' do
    before do
      allow(Rails.logger).to receive(:warn)
    end

    it 'returns a URL when work_id resolves to a record with type' do
      allow(described_class).to receive(:fetch_work_data_by_id)
        .with('abc123')
        .and_return({ work_id: 'abc123', work_type: 'Article' })

      expect(described_class.generate_cdr_url(work_id: 'abc123'))
        .to eq("#{host}/concern/articles/abc123")
    end

    it 'raises when HYRAX_HOST is not set' do
      allow(ENV).to receive(:[]).with('HYRAX_HOST').and_return(nil)

      allow(described_class).to receive(:fetch_work_data_by_id).with('abc123')
        .and_return({ work_id: 'abc123', work_type: 'Article' })

      described_class.generate_cdr_url(work_id: 'abc123')
      expect(Rails.logger).to have_received(:warn).with('[CDR_URL] Failed (work_id="abc123", identifier=nil): RuntimeError: HYRAX_HOST not set')
    end

    it 'returns nil and logs when no Solr record is found' do
      allow(described_class).to receive(:fetch_work_data_by_alternate_identifier)
        .with('PMC999')
        .and_return(nil)

      expect(described_class.generate_cdr_url(identifier: 'PMC999')).to be_nil
      expect(Rails.logger).to have_received(:warn).with('[CDR_URL] No Solr record found {:identifier=>"PMC999"}')
    end

    it 'returns nil and logs when work_type is missing' do
      allow(described_class).to receive(:fetch_work_data_by_id)
        .with('abc123')
        .and_return({ work_id: 'abc123', work_type: nil })

      expect(described_class.generate_cdr_url(work_id: 'abc123')).to be_nil
      expect(Rails.logger).to have_received(:warn).with('[CDR_URL] Missing work_type {:work_id=>"abc123"}')
    end

    it 'raises ArgumentError when both work_id and identifier are blank' do
      expect(described_class.generate_cdr_url).to be_nil
      expect(Rails.logger).to have_received(:warn).with('[CDR_URL] Failed (work_id=nil, identifier=nil): ArgumentError: Provide either work_id or identifier')
    end

    it 'rescues build failures, logs, and returns nil' do
      allow(described_class).to receive(:fetch_work_data_by_id)
        .with('abc123')
        .and_return({ work_id: 'abc123', work_type: 'Article' })
      allow(ENV).to receive(:[]).with('HYRAX_HOST').and_return(nil) # triggers build_cdr_url raise

      expect(described_class.generate_cdr_url(work_id: 'abc123')).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/^\[CDR_URL\] Failed \(work_id="abc123", identifier=nil\): RuntimeError: HYRAX_HOST not set$/)
    end
  end

  describe '#fetch_model_instance' do
    it 'raises ArgumentError when required args are missing' do
      expect { described_class.fetch_model_instance(nil, 'id') }
        .to raise_error(ArgumentError, 'Both work_type and work_id are required')
      expect { described_class.fetch_model_instance('Article', nil) }
        .to raise_error(ArgumentError, 'Both work_type and work_id are required')
    end

    it 'returns nil and logs on NameError (bad class)' do
      allow(Rails.logger).to receive(:error)
      expect(described_class.fetch_model_instance('NotARealModel', 'id')).to be_nil
      expect(Rails.logger).to have_received(:error).with(/\[WorkUtils\] Failed to fetch model instance: uninitialized constant/i)
    end

    it 'returns the model instance when found' do
      article = FactoryBot.create(:article)
      found = described_class.fetch_model_instance('Article', article.id)
      expect(found).to be_a(Article)
      expect(found.id).to eq(article.id)
    end
  end

  describe '#find_best_work_match_by_alternate_id' do
    let(:alternate_ids) { { pmid: '123456', pmcid: 'PMC789012', doi: '10.1000/example' } }

    context 'when DOI matches existing work' do
      let(:work_data) { { work_id: 'work_123', work_type: 'Article' } }

      before do
        allow(described_class).to receive(:fetch_work_data_by_doi)
          .with('10.1000/example').and_return(work_data)
      end

      it 'returns work data for DOI match' do
        result = described_class.send(:find_best_work_match_by_alternate_id, **alternate_ids)
        expect(result).to eq(work_data)
      end
    end

    context 'when PMCID matches existing work' do
      let(:work_data) { { work_id: 'work_456', work_type: 'Article' } }

      before do
        allow(described_class).to receive(:fetch_work_data_by_alternate_identifier)
          .with('10.1000/example').and_return(nil)
        allow(described_class).to receive(:fetch_work_data_by_alternate_identifier)
          .with('PMC789012').and_return(work_data)
      end

      it 'returns work data for PMCID match' do
        result = described_class.send(:find_best_work_match_by_alternate_id, **alternate_ids)
        expect(result).to eq(work_data)
      end
    end

    context 'when no matches found' do
      before do
        allow(described_class).to receive(:fetch_work_data_by_doi).and_return(nil)
        allow(described_class).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      end

      it 'returns nil' do
        result = described_class.send(:find_best_work_match_by_alternate_id, **alternate_ids)
        expect(result).to be_nil
      end
    end
  end
end
