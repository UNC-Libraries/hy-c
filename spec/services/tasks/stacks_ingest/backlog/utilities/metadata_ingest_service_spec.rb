# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::StacksIngest::Backlog::Utilities::MetadataIngestService do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['CDC Stacks Admin Set']) }
  let(:depositor) { FactoryBot.create(:user, uid: 'testuser') }
  let(:config) do
    {
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => depositor.uid,
      'output_dir' => '/tmp/stacks_output',
      'input_csv_path' => '/tmp/stacks_data.csv',
      'full_text_dir' => '/tmp/stacks_full_text'
    }
  end
  let(:tracker) { Tasks::StacksIngest::Backlog::Utilities::StacksIngestTracker.new(config) }
  let(:md_ingest_results_path) { '/tmp/stacks_md_results.jsonl' }

  let(:csv_data) do
    <<~CSV
      cdc_id,stacks_url,doi,pmid,pmcid,cdr_url,has_fileset,main_file,supplemental_files
      79129,https://stacks.cdc.gov/view/cdc/79129,http://dx.doi.org/10.1353/cpr.2018.0010,29606697,PMC6542568,,,cdc_79129_DS1.pdf,cdc_79129_DS2.gif
      140512,https://stacks.cdc.gov/view/cdc/140512,,,,,,cdc_140512_DS1.pdf,""
      151720,https://stacks.cdc.gov/view/cdc/151720,,37714542,PMC10940227,,,,"",""
      999999,https://stacks.cdc.gov/view/cdc/999999,http://dx.doi.org/10.9999/test,,,,cdc_999999_DS1.pdf,""
    CSV
  end

  let(:existing_results) do
    [
      { ids: { cdc_id: '79129', work_id: 'existing123' }, category: 'successfully_ingested_metadata_only' }.to_json
    ]
  end

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      md_ingest_results_path: md_ingest_results_path
    )
  end

  before do
    File.write(config['input_csv_path'], csv_data)
    allow(AdminSet).to receive(:where).with(title: admin_set.title.first).and_return([admin_set])
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  after do
    File.delete(config['input_csv_path']) if File.exist?(config['input_csv_path'])
    File.delete(md_ingest_results_path) if File.exist?(md_ingest_results_path)
  end

  describe '#initialize' do
    it 'sets instance variables from config' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@output_dir)).to eq('/tmp/stacks_output')
      expect(service.instance_variable_get(:@input_csv_path)).to eq('/tmp/stacks_data.csv')
      expect(service.instance_variable_get(:@md_ingest_results_path)).to eq(md_ingest_results_path)
      expect(service.instance_variable_get(:@admin_set)).to eq(admin_set)
    end

    it 'initializes write buffer and flush threshold' do
      expect(service.instance_variable_get(:@write_buffer)).to eq([])
      expect(service.instance_variable_get(:@flush_threshold)).to eq(100)
    end

    it 'loads seen identifiers from results file' do
      File.write(md_ingest_results_path, existing_results.join("\n"))

      new_service = described_class.new(
        config: config,
        tracker: tracker,
        md_ingest_results_path: md_ingest_results_path
      )

      seen_ids = new_service.instance_variable_get(:@seen_identifier_list)
      expect(seen_ids).to include('79129')
    end

    it 'initializes empty set when results file does not exist' do
      seen_ids = service.instance_variable_get(:@seen_identifier_list)
      expect(seen_ids).to be_a(Set)
      expect(seen_ids).to be_empty
    end
  end

  describe '#identifier_key_name' do
    it 'returns "cdc_id"' do
      expect(service.identifier_key_name).to eq('cdc_id')
    end
  end

  describe '#process_backlog' do
    let(:article) { FactoryBot.create(:article) }
    let(:doi_resolver) { instance_double(Tasks::IngestHelperUtils::DoiMetadataResolver) }
    let(:oai_resolver) { instance_double(Tasks::IngestHelperUtils::OaiPmhMetadataResolver) }
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::OaiPmhAttributeBuilder) }
    let(:resolved_metadata) { { 'title' => 'Test Article', 'cdc_id' => '140512' } }

    before do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(service).to receive(:new_article).and_return(article)
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
      allow(service).to receive(:sleep)
      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new).and_return(doi_resolver)
      allow(Tasks::IngestHelperUtils::OaiPmhMetadataResolver).to receive(:new).and_return(oai_resolver)
      allow(doi_resolver).to receive(:resolve_and_build).and_return(attr_builder)
      allow(doi_resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
      allow(oai_resolver).to receive(:resolve_and_build).and_return(attr_builder)
      allow(oai_resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
    end

    context 'with DOI present' do
      it 'uses DoiMetadataResolver' do
        service.process_backlog

        expect(Tasks::IngestHelperUtils::DoiMetadataResolver).to have_received(:new).with(
          doi: 'http://dx.doi.org/10.9999/test',
          admin_set: admin_set,
          depositor_onyen: depositor.uid
        )
      end

      it 'creates article with DOI metadata' do
        service.process_backlog

        expect(service).to have_received(:new_article).with(
          metadata: resolved_metadata,
          attr_builder: attr_builder,
          config: config,
          cdc_id: '999999'
        )
      end
    end

    context 'with no DOI (uses OAI-PMH)' do
      it 'uses OaiPmhMetadataResolver' do
        service.process_backlog

        expect(Tasks::IngestHelperUtils::OaiPmhMetadataResolver).to have_received(:new).with(
          id: '140512',
          identifier_key_name: 'cdc_id',
          full_text_dir: '/tmp/stacks_full_text',
          admin_set: admin_set,
          depositor_onyen: depositor.uid
        )
      end

      it 'creates article with OAI-PMH metadata' do
        service.process_backlog

        expect(service).to have_received(:new_article).with(
          metadata: resolved_metadata,
          attr_builder: attr_builder,
          config: config,
          cdc_id: '140512'
        )
      end
    end

    context 'when work already exists' do
      let(:existing_match) { { work_id: 'existing123', work_type: 'Article' } }
      let(:existing_article) { FactoryBot.create(:article) }

      before do
        # Stub for all rows to return nil except '140512'
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
          .with('140512', admin_set_title: admin_set.title.first)
          .and_return(existing_match)
        allow(WorkUtilsHelper).to receive(:fetch_model_instance)
          .with('Article', 'existing123')
          .and_return(existing_article)
      end

      it 'skips the work and records skip result' do
        service.process_backlog

        expect(Rails.logger).to have_received(:info).with(
          '[MetadataIngestService] Skipping work with cdc_id 140512 — already exists.'
        )
        expect(service).to have_received(:record_result).with(
          category: :skipped,
          message: 'Pre-filtered: work exists',
          identifier: '140512',
          article: existing_article,
          filename: 'cdc_140512_DS1.pdf'
        )
      end
    end

    context 'when ID already in seen list' do
      before do
        service.instance_variable_get(:@seen_identifier_list) << '140512'
      end

      it 'skips the ID entirely' do
        service.process_backlog

        expect(WorkUtilsHelper).not_to have_received(:fetch_work_data_by_alternate_identifier)
          .with('140512', admin_set_title: anything)
      end
    end

    context 'when metadata resolution raises error' do
      before do
        allow(doi_resolver).to receive(:resolve_and_build).and_raise(StandardError.new('API error'))
      end

      it 'handles error and records failure' do
        service.process_backlog

        expect(Rails.logger).to have_received(:error).with(
          '[MetadataIngestService] Error processing work with cdc_id 999999: API error'
        )
        expect(service).to have_received(:record_result).with(
          category: :failed,
          message: 'API error',
          identifier: '79129',
          article: nil,
          filename: 'cdc_79129_DS1.pdf'
        )
      end

      it 'logs backtrace' do
        service.process_backlog

        expect(Rails.logger).to have_received(:error).at_least(:twice)
      end
    end

    context 'when article creation raises error' do
      before do
        allow(service).to receive(:new_article).and_raise(StandardError.new('Save failed'))
      end

      it 'handles error and records failure' do
        service.process_backlog

        expect(service).to have_received(:record_result).at_least(:once).with(
          category: :failed,
          message: 'Save failed',
          identifier: anything,
          article: nil,
          filename: anything
        )
      end
    end

    it 'sleeps after each record for rate limiting' do
      service.process_backlog

      # Should sleep after each CSV row (3 rows without existing result)
      expect(service).to have_received(:sleep).with(3).at_least(:once)
    end

    it 'flushes buffer if needed after each record' do
      service.process_backlog

      expect(service).to have_received(:flush_buffer_if_needed).at_least(:once)
    end

    it 'flushes buffer at end if not empty' do
      service.instance_variable_set(:@write_buffer, [{ test: 'data' }])

      service.process_backlog

      expect(service).to have_received(:flush_buffer_to_file)
    end

    it 'logs completion message' do
      service.process_backlog

      expect(LogUtilsHelper).to have_received(:double_log).with(
        /Ingest complete\. Processed \d+ IDs\./,
        :info,
        tag: 'MetadataIngestService'
      )
    end

    it 'logs article creation for each successful record' do
      service.process_backlog

      expect(Rails.logger).to have_received(:info).with(
        /\[MetadataIngestService\] Created new Article .+ for publication with Stacks ID/
      ).at_least(:once)
    end
  end

  describe '#new_article' do
    let(:article) { Article.new }
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::OaiPmhAttributeBuilder) }
    let(:metadata) { { 'title' => 'Test Article' } }
    let(:cdc_id) { '140512' }

    before do
      allow(Article).to receive(:new).and_return(article)
      allow(attr_builder).to receive(:populate_article_metadata).and_return(article)
      allow(article).to receive(:save!)
      allow(article).to receive(:visibility=)
      allow(article).to receive(:identifier).and_return([])
      allow(article).to receive(:id).and_return('new_article_123')
      allow(service).to receive(:sync_permissions_and_state!)
    end

    it 'creates new article with private visibility' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, cdc_id: cdc_id)

      expect(article).to have_received(:visibility=).with(Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    end

    it 'populates metadata using attribute builder' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, cdc_id: cdc_id)

      expect(attr_builder).to have_received(:populate_article_metadata).with(article)
    end

    it 'adds CDC Stacks ID to identifiers' do
      identifiers = []
      allow(article).to receive(:identifier).and_return(identifiers)

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, cdc_id: cdc_id)

      expect(identifiers).to include('CDC-Stacks ID: 140512')
    end

    it 'saves the article' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, cdc_id: cdc_id)

      expect(article).to have_received(:save!)
    end

    it 'syncs permissions and state' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, cdc_id: cdc_id)

      expect(service).to have_received(:sync_permissions_and_state!).with(
        work_id: 'new_article_123',
        depositor_uid: depositor.uid,
        admin_set: admin_set
      )
    end

    it 'returns the article' do
      result = service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, cdc_id: cdc_id)

      expect(result).to eq(article)
    end
  end

  describe '#resolve_attr_builder_and_metadata_for_row' do
    let(:row) { CSV::Row.new(['cdc_id', 'doi'], ['140512', 'http://dx.doi.org/10.1234/test']) }
    let(:doi_resolver) { instance_double(Tasks::IngestHelperUtils::DoiMetadataResolver) }
    let(:oai_resolver) { instance_double(Tasks::IngestHelperUtils::OaiPmhMetadataResolver) }
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder) }
    let(:resolved_metadata) { { 'title' => 'Test' } }

    before do
      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new).and_return(doi_resolver)
      allow(oai_resolver).to receive(:resolve_and_build).and_return(attr_builder)
      allow(oai_resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
      allow(doi_resolver).to receive(:resolve_and_build).and_return(attr_builder)
      allow(doi_resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
    end

    context 'when DOI is present' do
      it 'creates DoiMetadataResolver' do
        service.send(:resolve_attr_builder_and_metadata_for_row, row)

        expect(Tasks::IngestHelperUtils::DoiMetadataResolver).to have_received(:new).with(
          doi: 'http://dx.doi.org/10.1234/test',
          admin_set: admin_set,
          depositor_onyen: depositor.uid
        )
      end

      it 'returns attribute builder and metadata' do
        builder, metadata = service.send(:resolve_attr_builder_and_metadata_for_row, row)

        expect(builder).to eq(attr_builder)
        expect(metadata).to eq(resolved_metadata)
      end
    end

    context 'when DOI is blank' do
      let(:row_no_doi) { CSV::Row.new(['cdc_id', 'doi'], ['140512', '']) }
      let(:oai_resolver) { instance_double(Tasks::IngestHelperUtils::OaiPmhMetadataResolver) }

      before do
        allow(Tasks::IngestHelperUtils::OaiPmhMetadataResolver).to receive(:new).and_return(oai_resolver)
        allow(oai_resolver).to receive(:resolve_and_build).and_return(attr_builder)
        allow(oai_resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
      end

      it 'creates OaiPmhMetadataResolver' do
        service.send(:resolve_attr_builder_and_metadata_for_row, row_no_doi)

        expect(Tasks::IngestHelperUtils::OaiPmhMetadataResolver).to have_received(:new).with(
          id: '140512',
          identifier_key_name: 'cdc_id',
          full_text_dir: '/tmp/stacks_full_text',
          admin_set: admin_set,
          depositor_onyen: depositor.uid
        )
      end

      it 'returns attribute builder and metadata' do
        builder, metadata = service.send(:resolve_attr_builder_and_metadata_for_row, row_no_doi)

        expect(builder).to eq(attr_builder)
        expect(metadata).to eq(resolved_metadata)
      end
    end

    context 'when cdc_id is blank' do
      let(:row_no_id) { CSV::Row.new(['cdc_id', 'doi'], ['', 'http://dx.doi.org/10.1234/test']) }

      it 'raises ArgumentError' do
        expect {
          service.send(:resolve_attr_builder_and_metadata_for_row, row_no_id)
        }.to raise_error(ArgumentError, 'Stacks ID cannot be blank')
      end
    end

    context 'when doi resolver raises error' do
      before do
        allow(doi_resolver).to receive(:resolve_and_build).and_raise(StandardError.new('Resolution failed'))
        allow(Tasks::IngestHelperUtils::OaiPmhMetadataResolver).to receive(:new).and_return(oai_resolver)
        allow(oai_resolver).to receive(:resolve_and_build).and_return(attr_builder)
        allow(oai_resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
      end

      it 'logs error and falls back to OAI-PMH resolver' do
        builder, metadata = service.send(:resolve_attr_builder_and_metadata_for_row, row)

        expect(Rails.logger).to have_received(:warn).with(
          '[MetadataIngestService] DOI resolution failed for DOI http://dx.doi.org/10.1234/test (Stacks ID 140512): Resolution failed. Falling back to OAI-PMH.'
        )
        expect(Tasks::IngestHelperUtils::OaiPmhMetadataResolver).to have_received(:new).with(
          id: '140512',
          identifier_key_name: 'cdc_id',
          full_text_dir: '/tmp/stacks_full_text',
          admin_set: admin_set,
          depositor_onyen: depositor.uid
        )
        expect(builder).to eq(attr_builder)
        expect(metadata).to eq(resolved_metadata)
      end
    end
  end

  describe '#remaining_rows_from_csv' do
    it 'returns all CSV rows when seen list is empty' do
      rows = service.send(:remaining_rows_from_csv, config['input_csv_path'])

      expect(rows.size).to eq(4)
      expect(rows.map { |r| r['cdc_id'] }).to contain_exactly('79129', '140512', '151720', '999999')
    end

    it 'filters out rows in seen list' do
      service.instance_variable_get(:@seen_identifier_list) << '79129'
      service.instance_variable_get(:@seen_identifier_list) << '140512'

      rows = service.send(:remaining_rows_from_csv, config['input_csv_path'])

      expect(rows.size).to eq(2)
      expect(rows.map { |r| r['cdc_id'] }).to contain_exactly('151720', '999999')
    end

    it 'returns empty array when all rows are in seen list' do
      service.instance_variable_get(:@seen_identifier_list) << '79129'
      service.instance_variable_get(:@seen_identifier_list) << '140512'
      service.instance_variable_get(:@seen_identifier_list) << '151720'
      service.instance_variable_get(:@seen_identifier_list) << '999999'

      rows = service.send(:remaining_rows_from_csv, config['input_csv_path'])

      expect(rows).to be_empty
    end

    it 'preserves all CSV columns in returned rows' do
      rows = service.send(:remaining_rows_from_csv, config['input_csv_path'])
      row = rows.first

      expect(row).to have_key('cdc_id')
      expect(row).to have_key('doi')
      expect(row).to have_key('pmid')
      expect(row).to have_key('main_file')
      expect(row).to have_key('supplemental_files')
    end
  end

  describe 'integration with helper modules' do
    it 'includes IngestHelper' do
      expect(service.class.ancestors).to include(Tasks::IngestHelperUtils::IngestHelper)
    end

    it 'includes MetadataIngestHelper' do
      expect(service.class.ancestors).to include(Tasks::IngestHelperUtils::MetadataIngestHelper)
    end

    it 'has access to IngestHelper methods' do
      expect(service).to respond_to(:attach_pdf_to_work_with_file_path!)
      expect(service).to respond_to(:sync_permissions_and_state!)
    end

    it 'has access to MetadataIngestHelper methods' do
      expect(service).to respond_to(:record_result)
      expect(service).to respond_to(:flush_buffer_to_file)
      expect(service).to respond_to(:skip_existing_work)
      expect(service).to respond_to(:handle_record_error)
    end
  end
end
