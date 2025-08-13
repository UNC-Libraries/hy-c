# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService do
  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  let(:progress_hash) do
    {
        'retrieve_ids_within_date_range' => {
        'pubmed' => { 'cursor' => 0 },
        'pmc'    => { 'cursor' => 0 }
        },
        'stream_and_write_alternate_ids' => {
        'pubmed' => { 'cursor' => 0 },
        'pmc'    => { 'cursor' => 0 }
        },
        'adjust_id_lists' => {
        'completed' => false,
        'pubmed'    => {},
        'pmc'       => {}
        }
    }
  end
  let(:tracker) { double('tracker', save: true) }
  let(:service) { described_class.new(start_date: start_date, end_date: end_date, tracker: tracker) }
  let(:temp_file) { Tempfile.new('test') }
  let(:output_path) { temp_file.path }

  before do
    allow(tracker).to receive(:[]).with('progress').and_return(progress_hash)
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:error)
  end

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(service.instance_variable_get(:@start_date)).to eq(start_date)
      expect(service.instance_variable_get(:@end_date)).to eq(end_date)
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
    end
  end

  describe '#retrieve_ids_within_date_range' do
    let(:mock_response) do
      double('response',
        code: 200,
        message: 'OK',
        body: xml_response_body
      )
    end

    let(:xml_response_body) do
      <<~XML
        <?xml version="1.0"?>
        <eSearchResult>
          <Count>2</Count>
          <IdList>
            <Id>123456</Id>
            <Id>789012</Id>
          </IdList>
        </eSearchResult>
      XML
    end

    before do
      allow(HTTParty).to receive(:get).and_return(mock_response)
      allow(File).to receive(:open).with(output_path, 'a').and_yield(temp_file)
    end

    context 'with pubmed database' do
      it 'retrieves and writes IDs correctly' do
        service.retrieve_ids_within_date_range(output_path: output_path, db: 'pubmed')

        temp_file.rewind
        lines = temp_file.readlines

        expect(lines.size).to eq(2)
        first_entry = JSON.parse(lines[0])
        expect(first_entry).to eq({ 'index' => 0, 'id' => '123456' })

        second_entry = JSON.parse(lines[1])
        expect(second_entry).to eq({ 'index' => 1, 'id' => '789012' })
      end

      it 'makes correct API call' do
        service.retrieve_ids_within_date_range(output_path: output_path, db: 'pubmed')

        expect(HTTParty).to have_received(:get).with(
          'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi',
          query: hash_including(
            db: 'pubmed',
            retmax: 200,
            retmode: 'xml',
            tool: 'CDR',
            email: 'cdr@unc.edu',
            retstart: 0,
            # Contains AD affiliation OR-clause and date range
            term: a_string_matching(/\(.*\[AD\].*OR.*\[AD\].*\)\s+AND\s+2024\/01\/01:2024\/01\/31\[PDAT\]/)
          )
        )
      end
    end

    context 'with pmc database' do
      it 'prefixes PMC IDs correctly' do
        service.retrieve_ids_within_date_range(output_path: output_path, db: 'pmc')

        temp_file.rewind
        lines = temp_file.readlines

        first_entry = JSON.parse(lines[0])
        expect(first_entry['id']).to eq('PMC123456')

        second_entry = JSON.parse(lines[1])
        expect(second_entry['id']).to eq('PMC789012')
      end
    end

    context 'when API returns error' do
      let(:error_response) { double('response', code: 500, message: 'Internal Server Error') }

      before do
        allow(HTTParty).to receive(:get).and_return(error_response)
      end

      it 'logs error and breaks loop' do
        service.retrieve_ids_within_date_range(output_path: output_path, db: 'pubmed')

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Failed to retrieve IDs: 500 - Internal Server Error',
          :error,
          tag: 'retrieve_ids_within_date_range'
        )
      end
    end

    context 'with cursor tracking' do
      before do
        tracker['progress']['retrieve_ids_within_date_range']['pubmed']['cursor'] = 1000
      end

      it 'starts from cursor position' do
        service.retrieve_ids_within_date_range(output_path: output_path, db: 'pubmed')

        expect(HTTParty).to have_received(:get).with(
          'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi',
          query: hash_including(
            db: 'pubmed',
            retmax: 200,
            retmode: 'xml',
            tool: 'CDR',
            email: 'cdr@unc.edu',
            retstart: 1000,
            # now expects UNC [AD] OR-clause AND date range
            term: a_string_matching(/\(.*\[AD\].*OR.*\[AD\].*\)\s+AND\s+2024\/01\/01:2024\/01\/31\[PDAT\]/)
          )
        )
      end
    end
  end

  describe '#stream_and_write_alternate_ids' do
    let(:input_file_content) do
      [
        { 'index' => 0, 'id' => 'PMC123456' }.to_json,
        { 'index' => 1, 'id' => 'PMC789012' }.to_json
      ].join("\n")
    end

    let(:input_temp_file) { Tempfile.new('input') }
    let(:output_temp_file) { Tempfile.new('output') }

    before do
      input_temp_file.write(input_file_content)
      input_temp_file.rewind

      allow(service).to receive(:write_batch_alternate_ids)
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(output_temp_file.path, 'w').and_yield(output_temp_file)
      allow(File).to receive(:foreach).with(input_temp_file.path).and_yield(input_file_content.lines[0]).and_yield(input_file_content.lines[1])
    end

    after do
      input_temp_file.close
      input_temp_file.unlink
      output_temp_file.close
      output_temp_file.unlink
    end

    it 'processes IDs in batches' do
      service.stream_and_write_alternate_ids(
        input_path: input_temp_file.path,
        output_path: output_temp_file.path,
        db: 'pmc',
        batch_size: 2
      )

      expect(service).to have_received(:write_batch_alternate_ids).with(
        ids: ['PMC123456', 'PMC789012'],
        db: 'pmc',
        output_file: output_temp_file
      )
    end

    context 'with cursor tracking' do
      before do
        tracker['progress']['stream_and_write_alternate_ids']['pmc']['cursor'] = 1
      end

      it 'skips IDs before cursor position' do
        service.stream_and_write_alternate_ids(
          input_path: input_temp_file.path,
          output_path: output_temp_file.path,
          db: 'pmc',
          batch_size: 2
        )

        expect(service).to have_received(:write_batch_alternate_ids).with(
          ids: ['PMC789012'],
          db: 'pmc',
          output_file: output_temp_file
        )
      end
    end
  end

  describe '#write_batch_alternate_ids' do
    let(:ids) { ['PMC123456', 'PMC789012'] }
    let(:output_file) { double('file') }
    let(:mock_response) do
      double('response',
        code: 200,
        body: xml_conversion_response
      )
    end

    let(:xml_conversion_response) do
      <<~XML
        <?xml version="1.0"?>
        <pmcids status="ok">
          <record pmcid="PMC123456" pmid="987654" doi="10.1000/example1" status="ok"/>
          <record pmcid="PMC789012" pmid="111222" doi="10.1000/example2" status="error"/>
        </pmcids>
      XML
    end

    before do
      allow(HTTParty).to receive(:get).and_return(mock_response)
      allow(output_file).to receive(:puts)
      allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_alternate_id).and_return('http://example.com/cdr')
    end

    it 'makes correct API call to ID conversion service' do
      expected_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=PMC123456,PMC789012&tool=CDR&email=cdr@unc.edu&retmode=xml'

      service.write_batch_alternate_ids(ids: ids, db: 'pmc', output_file: output_file)

      expect(HTTParty).to have_received(:get).with(expected_url)
    end

    it 'writes alternate IDs for successful records' do
      expected_output = {
        'pmid' => '987654',
        'pmcid' => 'PMC123456',
        'doi' => '10.1000/example1',
        'cdr_url' => 'http://example.com/cdr'
      }

      service.write_batch_alternate_ids(ids: ids, db: 'pmc', output_file: output_file)

      expect(output_file).to have_received(:puts).with(expected_output.to_json)
    end

    it 'writes error status for failed records' do
      expected_error_output = {
        'pmid' => '111222',
        'pmcid' => 'PMC789012',
        'doi' => '10.1000/example2',
        'error' => 'error',
        'cdr_url' => 'http://example.com/cdr'
      }

      service.write_batch_alternate_ids(ids: ids, db: 'pmc', output_file: output_file)

      expect(output_file).to have_received(:puts).with(expected_error_output.to_json)
    end

    context 'when API call fails' do
      before do
        allow(HTTParty).to receive(:get).and_raise(StandardError.new('Network error'))
      end

      it 'logs error and continues' do
        expect {
          service.write_batch_alternate_ids(ids: ids, db: 'pmc', output_file: output_file)
        }.not_to raise_error

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Error converting IDs: Network error',
          :error,
          tag: 'write_batch_alternate_ids'
        )
      end
    end
  end

  describe '#adjust_id_lists' do
    let(:pubmed_temp_file) { Tempfile.new('pubmed') }
    let(:pmc_temp_file) { Tempfile.new('pmc') }
    let(:pubmed_records) do
      [
        { 'pmid' => '123', 'doi' => 'doi1', 'pmcid' => nil }.to_json,
        { 'pmid' => '456', 'doi' => 'doi2', 'pmcid' => nil }.to_json
      ]
    end
    let(:pmc_records) do
      [
        { 'pmcid' => 'PMC111', 'pmid' => '789', 'doi' => 'doi3' }.to_json,
        { 'pmcid' => 'PMC222', 'pmid' => '123', 'doi' => 'doi1' }.to_json  # duplicate doi
      ]
    end

    before do
      pubmed_temp_file.write(pubmed_records.join("\n"))
      pubmed_temp_file.rewind

      pmc_temp_file.write(pmc_records.join("\n"))
      pmc_temp_file.rewind

      allow(File).to receive(:readlines).with(pubmed_temp_file.path).and_return(pubmed_records)
      allow(File).to receive(:readlines).with(pmc_temp_file.path).and_return(pmc_records)
      allow(File).to receive(:open).and_call_original
    end

    after do
      pubmed_temp_file.close
      pubmed_temp_file.unlink
      pmc_temp_file.close
      pmc_temp_file.unlink
    end

    context 'when adjustment not completed' do
      it 'deduplicates records and updates tracker' do
        service.adjust_id_lists(pubmed_path: pubmed_temp_file.path, pmc_path: pmc_temp_file.path)

        expect(tracker['progress']['adjust_id_lists']['completed']).to be true
        expect(tracker['progress']['adjust_id_lists']['pubmed']['original_size']).to eq(2)
        expect(tracker['progress']['adjust_id_lists']['pmc']['original_size']).to eq(2)
      end

      it 'logs adjustment summary' do
        service.adjust_id_lists(pubmed_path: pubmed_temp_file.path, pmc_path: pmc_temp_file.path)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          /Adjusted ID lists - PubMed: \d+ ➝ \d+, PMC: \d+ ➝ \d+/,
          :info,
          tag: 'adjust_id_lists'
        )
      end
    end

    context 'when adjustment already completed' do
      before do
        tracker['progress']['adjust_id_lists']['completed'] = true
      end

      it 'skips adjustment and logs message' do
        expect(File).not_to receive(:readlines)

        service.adjust_id_lists(pubmed_path: pubmed_temp_file.path, pmc_path: pmc_temp_file.path)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'ID lists already adjusted. Skipping adjustment step.',
          :info,
          tag: 'adjust_id_lists'
        )
      end
    end
  end

  describe '#pubmed_affiliation_clause' do
    it 'wraps UNC terms as an OR [AD] clause' do
      stub_const("#{described_class}::UNC_AFFILIATION_TERMS", ['UNC Chapel Hill', 'UNCCH'])
      clause = service.send(:pubmed_affiliation_clause)
      expect(clause).to eq('("UNC Chapel Hill"[AD] OR "UNCCH"[AD])')
    end
  end

  describe '#build_pubmed_term' do
    it 'builds affiliation AND date' do
      stub_const("#{described_class}::UNC_AFFILIATION_TERMS", ['UNC Chapel Hill'])
      term = service.send(:build_pubmed_term,
        start_date: start_date,
        end_date: end_date,
        extras: nil
      )
      expect(term).to match(/^\("UNC Chapel Hill"\[AD\]\)\s+AND\s+2024\/01\/01:2024\/01\/31\[PDAT\]$/)
    end

    it 'appends extras with AND' do
      stub_const("#{described_class}::UNC_AFFILIATION_TERMS", ['UNCCH'])
      term = service.send(:build_pubmed_term,
        start_date: start_date,
        end_date: end_date,
        extras: 'open access[filter]'
      )
      expect(term).to match(/\("UNCCH"\[AD\]\)\s+AND\s+2024\/01\/01:2024\/01\/31\[PDAT\]\s+AND\s+open access\[filter\]$/)
    end
  end

  describe '#build_search_terms' do
    it 'uses pubmed term with affiliation + date' do
      stub_const("#{described_class}::UNC_AFFILIATION_TERMS", ['UNC Chapel Hill'])
      term = service.send(:build_search_terms, db: 'pubmed', start_date: start_date, end_date: end_date, extras: nil)
      expect(term).to include('"UNC Chapel Hill"[AD]')
      expect(term).to include('2024/01/01:2024/01/31[PDAT]')
    end

    it 'uses date-only term for pmc' do
      term = service.send(:build_search_terms, db: 'pmc', start_date: start_date, end_date: end_date, extras: 'ignored')
      expect(term).to eq('2024/01/01:2024/01/31[PDAT]')
    end
  end


  describe 'private methods' do
    describe '#dedup_key' do
      it 'returns doi when present' do
        record = { 'doi' => 'test_doi', 'pmcid' => 'PMC123', 'pmid' => '456' }
        key = service.send(:dedup_key, record)
        expect(key).to eq('test_doi')
      end

      it 'returns pmcid when doi is blank' do
        record = { 'doi' => '', 'pmcid' => 'PMC123', 'pmid' => '456' }
        key = service.send(:dedup_key, record)
        expect(key).to eq('PMC123')
      end

      it 'returns pmid when doi and pmcid are blank' do
        record = { 'doi' => nil, 'pmcid' => '', 'pmid' => '456' }
        key = service.send(:dedup_key, record)
        expect(key).to eq('456')
      end
    end

    describe '#deduplicate_pmc_records' do
      let(:records) do
        [
          { 'pmcid' => 'PMC123', 'doi' => 'doi1' },
          { 'pmcid' => 'PMC456', 'doi' => 'doi1' },  # duplicate doi
          { 'pmcid' => '', 'doi' => 'doi2' },        # blank pmcid
          { 'pmcid' => 'PMC789', 'doi' => 'doi3' }
        ]
      end

      it 'removes duplicates and records with blank pmcids' do
        deduped, seen_keys = service.send(:deduplicate_pmc_records, records)

        expect(deduped.size).to eq(2)
        expect(deduped.map { |r| r['pmcid'] }).to contain_exactly('PMC123', 'PMC789')
        expect(seen_keys).to include('doi1', 'doi3')
      end
    end

    describe '#deduplicate_pubmed_records' do
      let(:records) do
        [
          { 'pmid' => '123', 'doi' => 'doi1' },
          { 'pmid' => '456', 'doi' => 'doi2' },
          { 'pmid' => '789', 'doi' => 'doi3' }
        ]
      end
      let(:seen_keys) { Set.new(['doi1']) }

      it 'removes records with keys already seen' do
        deduped = service.send(:deduplicate_pubmed_records, records, seen_keys)

        expect(deduped.size).to eq(2)
        expect(deduped.map { |r| r['doi'] }).to contain_exactly('doi2', 'doi3')
      end
    end
  end
end
