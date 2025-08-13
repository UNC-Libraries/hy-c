# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService do
  let(:config) do
    {
      'output_dir' => '/tmp/test_output',
      'admin_set_title' => 'Test Admin Set',
      'depositor_onyen' => 'test_user'
    }
  end
  let(:results) { { counts: { successfully_ingested: 0, skipped: 0, failed: 0 } } }
  let(:tracker) { double('tracker', save: true) }
  let(:results_path) { '/tmp/test_results.jsonl' }
  let(:mock_admin_set) { double('admin_set', id: 'admin_set_123', title: 'Test Admin Set') }

  let(:service) do
    described_class.new(
      config: config,
      results: results,
      tracker: tracker,
      results_path: results_path
    )
  end

  let(:sample_alternate_ids) do
    [
      { 'pmid' => '123456', 'pmcid' => 'PMC789012', 'doi' => '10.1000/example1' }.to_json,
      { 'pmid' => '234567', 'pmcid' => 'PMC890123', 'doi' => '10.1000/example2' }.to_json,
      { 'pmid' => '345678', 'pmcid' => 'PMC901234', 'doi' => '10.1000/example3' }.to_json
    ]
  end

  let(:sample_pubmed_xml) do
    <<~XML
      <?xml version="1.0"?>
      <PubmedArticleSet>
        <PubmedArticle>
          <MedlineCitation>
            <PMID Version="1">123456</PMID>
            <Article>
              <ArticleTitle>Sample Article Title</ArticleTitle>
            </Article>
          </MedlineCitation>
          <PubmedData>
            <ArticleIdList>
              <ArticleId IdType="pubmed">123456</ArticleId>
              <ArticleId IdType="pmc">PMC789012</ArticleId>
              <ArticleId IdType="doi">10.1000/example1</ArticleId>
            </ArticleIdList>
          </PubmedData>
        </PubmedArticle>
      </PubmedArticleSet>
    XML
  end

  let(:sample_pmc_xml) do
    <<~XML
      <?xml version="1.0"?>
      <pmc-articleset>
        <article>
          <front>
            <article-meta>
              <article-id pub-id-type="pmid">123456</article-id>
              <article-id pub-id-type="pmcid">PMC789012</article-id>
              <article-id pub-id-type="doi">10.1000/example1</article-id>
              <title-group>
                <article-title>Sample PMC Article</article-title>
              </title-group>
            </article-meta>
          </front>
        </article>
      </pmc-articleset>
    XML
  end

  let(:pmc_error_xml) do
    <<~XML
      <?xml version="1.0"?>
      <pmc-articleset>
        <error pmcid="PMC789012">Article not found</error>
      </pmc-articleset>
    XML
  end

  before do
    allow(AdminSet).to receive(:where).with(title: 'Test Admin Set').and_return([mock_admin_set])
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:debug)
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:foreach)
    allow(File).to receive(:readlines).and_return([])
    allow(File).to receive(:open)
    allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
    allow(WorkUtilsHelper).to receive(:fetch_model_instance)
    allow(HTTParty).to receive(:get)
  end

  describe '#initialize' do
    it 'sets up instance variables correctly' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@results)).to eq(results)
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
      expect(service.instance_variable_get(:@results_path)).to eq(results_path)
      expect(service.instance_variable_get(:@admin_set)).to eq(mock_admin_set)
      expect(service.instance_variable_get(:@write_buffer)).to eq([])
      expect(service.instance_variable_get(:@flush_threshold)).to eq(200)
    end
  end

  describe '#load_last_results' do
    context 'when results file does not exist' do
      before do
        allow(File).to receive(:exist?).with(results_path).and_return(false)
      end

      it 'returns empty set' do
        result = service.load_last_results
        expect(result).to be_a(Set)
        expect(result).to be_empty
      end
    end

    context 'when results file exists' do
      let(:existing_results) do
        [
          { ids: { pmid: '111111', pmcid: 'PMC222222' } }.to_json,
          { ids: { pmid: '333333', pmcid: 'PMC444444' } }.to_json
        ]
      end

      before do
        allow(File).to receive(:exist?).with(results_path).and_return(true)
        allow(File).to receive(:readlines).with(results_path).and_return(existing_results)
      end

      it 'returns set of existing IDs' do
        result = service.load_last_results
        expect(result).to include('111111', 'PMC222222', '333333', 'PMC444444')
      end
    end
  end

  describe '#load_alternate_ids_from_file' do
    let(:test_path) { '/tmp/test_alternate_ids.jsonl' }
    let(:mock_article) { double('article', id: 'existing_work_123') }

    before do
      allow(File).to receive(:foreach).with(test_path).and_yield(sample_alternate_ids[0]).and_yield(sample_alternate_ids[1])
      allow(service).to receive(:load_last_results).and_return(Set.new)
      allow(service).to receive(:find_best_work_match).and_return(nil)
      allow(service).to receive(:flush_buffer_to_file)
    end

    context 'when no existing records found' do
      it 'loads all records' do
        service.load_alternate_ids_from_file(path: test_path)

        record_ids = service.instance_variable_get(:@record_ids)
        expect(record_ids.size).to eq(2)
        expect(record_ids.first['pmid']).to eq('123456')
      end
    end

    context 'when some records already exist in results file' do
      before do
        allow(service).to receive(:load_last_results).and_return(Set.new(['123456']))
      end

      it 'skips existing records' do
        service.load_alternate_ids_from_file(path: test_path)

        record_ids = service.instance_variable_get(:@record_ids)
        expect(record_ids.size).to eq(1)
        expect(record_ids.first['pmid']).to eq('234567')
      end
    end

    context 'when work already exists in Hyrax' do
      before do
        allow(service).to receive(:find_best_work_match).and_return({
          work_id: 'existing_work_123',
          work_type: 'Article'
        })
        allow(WorkUtilsHelper).to receive(:fetch_model_instance).and_return(mock_article)
        allow(service).to receive(:record_result)
      end

      it 'skips existing works and records result' do
        service.load_alternate_ids_from_file(path: test_path)

        expect(service).to have_received(:record_result).with(
          category: :skipped,
          message: 'Pre-filtered: work exists',
          ids: JSON.parse(sample_alternate_ids[0]),
          article: mock_article
        )
      end
    end
  end

  describe '#batch_retrieve_and_process_metadata' do
    let(:mock_response) { double('response', code: 200, body: sample_pubmed_xml) }

    before do
      service.instance_variable_set(:@record_ids, [
        JSON.parse(sample_alternate_ids[0]),
        JSON.parse(sample_alternate_ids[1])
      ])
      allow(HTTParty).to receive(:get).and_return(mock_response)
      allow(service).to receive(:handle_pmc_errors)
      allow(service).to receive(:handle_pubmed_errors)
      allow(service).to receive(:process_batch)
      allow(service).to receive(:flush_buffer_to_file)
      allow(service).to receive(:sleep)
    end

    context 'with PubMed database' do
      it 'fetches metadata and processes batches' do
        service.batch_retrieve_and_process_metadata(batch_size: 2, db: 'pubmed')

        expect(HTTParty).to have_received(:get).with(
          'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=123456,234567&retmode=xml&tool=CDR&email=cdr@unc.edu'
        )
        expect(service).to have_received(:process_batch)
      end
    end

    context 'with PMC database' do
      let(:mock_pmc_response) { double('response', code: 200, body: sample_pmc_xml) }

      before do
        allow(HTTParty).to receive(:get).and_return(mock_pmc_response)
      end

      it 'fetches PMC metadata and strips PMC prefix from IDs' do
        service.batch_retrieve_and_process_metadata(batch_size: 2, db: 'pmc')

        expect(HTTParty).to have_received(:get).with(
          'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pmc&id=789012,890123&retmode=xml&tool=CDR&email=cdr@unc.edu'
        )
      end
    end

    context 'when API returns error' do
      let(:error_response) { double('response', code: 500, body: '', message: 'Internal Server Error') }

      before do
        allow(HTTParty).to receive(:get).and_return(error_response)
      end

      it 'logs error and continues processing' do
        service.batch_retrieve_and_process_metadata(batch_size: 2, db: 'pubmed')

        expect(Rails.logger).to have_received(:error).with(/Failed to fetch for IDs/)
      end
    end

    context 'when no record IDs are loaded' do
      before do
        service.instance_variable_set(:@record_ids, nil)
      end

      it 'returns early without processing' do
        service.batch_retrieve_and_process_metadata(batch_size: 2, db: 'pubmed')

        expect(HTTParty).not_to have_received(:get)
      end
    end
  end

  describe '#handle_pmc_errors' do
    let(:error_xml_doc) { Nokogiri::XML(pmc_error_xml) }

    before do
      allow(service).to receive(:retrieve_alternate_ids_for_doc).and_return({ 'pmid' => '123456' }.to_json)
      allow(service).to receive(:move_to_pubmed_alternate_ids_file)
    end

    it 'logs PMC errors and moves alternate IDs to PubMed file' do
      service.send(:handle_pmc_errors, error_xml_doc)

      expect(Rails.logger).to have_received(:warn).with(/PMC error for PMC789012/)
      expect(service).to have_received(:move_to_pubmed_alternate_ids_file)
    end
  end

  describe '#handle_pubmed_errors' do
    let(:pubmed_xml_doc) { Nokogiri::XML(sample_pubmed_xml) }
    let(:requested_ids) { ['123456', '999999'] } # Second ID won't be found

    before do
      allow(service).to receive(:record_result)
    end

    it 'identifies missing IDs and records failures' do
      service.send(:handle_pubmed_errors, pubmed_xml_doc, requested_ids)

      expect(service).to have_received(:record_result).with(
        category: :failed,
        message: 'EFetch: PubMed record not found',
        ids: { pmid: '999999' }
      )
    end
  end

  describe '#process_batch' do
    let(:pubmed_xml_doc) { Nokogiri::XML(sample_pubmed_xml) }
    let(:batch_articles) { pubmed_xml_doc.xpath('//PubmedArticle') }
    let(:mock_article) { double('article', save!: true, id: 'new_article_123', persisted?: true, destroy: true) }
    let(:alternate_ids) { { 'pmid' => '123456', 'pmcid' => 'PMC789012', 'doi' => '10.1000/example1' } }

    before do
      allow(service).to receive(:retrieve_alternate_ids_for_doc).and_return(alternate_ids)
      allow(service).to receive(:find_best_work_match).and_return(nil)
      allow(service).to receive(:new_article).and_return(mock_article)
      allow(service).to receive(:record_result)
    end

    context 'when work does not exist' do
      it 'creates new article and records success' do
        service.send(:process_batch, batch_articles)

        expect(service).to have_received(:new_article).with(batch_articles.first)
        expect(mock_article).to have_received(:save!)
        expect(service).to have_received(:record_result).with(
          category: :successfully_ingested,
          ids: alternate_ids,
          article: mock_article
        )
      end
    end

    context 'when work already exists' do
      let(:existing_work_match) do
        { work_id: 'existing_123', work_type: 'Article' }
      end
      let(:mock_existing_article) { double('existing_article') }

      before do
        allow(service).to receive(:find_best_work_match).and_return(existing_work_match)
        allow(WorkUtilsHelper).to receive(:fetch_model_instance).and_return(mock_existing_article)
      end

      it 'skips creation and records skip' do
        service.send(:process_batch, batch_articles)

        expect(service).not_to have_received(:new_article)
        expect(service).to have_received(:record_result).with(
          category: :skipped,
          ids: alternate_ids,
          message: 'Filtered after retrieving metadata: work exists',
          article: mock_existing_article
        )
      end
    end

    context 'when article creation fails' do
      before do
        allow(mock_article).to receive(:save!).and_raise(StandardError.new('Save failed'))
      end

      it 'destroys article and records failure' do
        service.send(:process_batch, batch_articles)

        expect(mock_article).to have_received(:destroy)
        expect(service).to have_received(:record_result).with(
          category: :failed,
          message: 'Save failed',
          ids: alternate_ids
        )
      end
    end
  end

  describe '#retrieve_alternate_ids_for_doc' do
    let(:pubmed_xml_doc) { Nokogiri::XML(sample_pubmed_xml) }
    let(:pubmed_article) { pubmed_xml_doc.xpath('//PubmedArticle').first }
    let(:pmc_xml_doc) { Nokogiri::XML(sample_pmc_xml) }
    let(:pmc_article) { pmc_xml_doc.xpath('//article').first }

    before do
      service.instance_variable_set(:@record_ids, [
        { 'pmid' => '123456', 'pmcid' => 'PMC789012' }
      ])
    end

    context 'with PubMed document' do
      it 'extracts PubMed IDs and finds matching record' do
        result = service.send(:retrieve_alternate_ids_for_doc, pubmed_article)

        expect(result).to eq({ 'pmid' => '123456', 'pmcid' => 'PMC789012' })
      end
    end

    context 'with PMC document' do
      it 'extracts PMC IDs and finds matching record' do
        result = service.send(:retrieve_alternate_ids_for_doc, pmc_article)

        expect(result).to eq({ 'pmid' => '123456', 'pmcid' => 'PMC789012' })
      end
    end

    context 'when document parsing fails' do
      before do
        allow(pubmed_article).to receive(:at_xpath).and_raise(StandardError.new('XML parsing error'))
      end

      it 'logs error and returns nil' do
        result = service.send(:retrieve_alternate_ids_for_doc, pubmed_article)

        expect(Rails.logger).to have_received(:error).with(/Error retrieving alternate IDs/)
        expect(result).to be_nil
      end
    end
  end

  describe '#new_article' do
    let(:pubmed_xml_doc) { Nokogiri::XML(sample_pubmed_xml) }
    let(:pubmed_article) { pubmed_xml_doc.xpath('//PubmedArticle').first }
    let(:mock_article) { double('article', visibility: nil, 'visibility=': nil) }
    let(:mock_builder) { double('builder', populate_article_metadata: true) }

    before do
      allow(Article).to receive(:new).and_return(mock_article)
      allow(service).to receive(:attribute_builder).and_return(mock_builder)
    end

    it 'creates new article with private visibility' do
      result = service.send(:new_article, pubmed_article)

      expect(Article).to have_received(:new)
      expect(mock_article).to have_received(:visibility=).with(
        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      )
      expect(service).to have_received(:attribute_builder).with(pubmed_article, mock_article)
      expect(mock_builder).to have_received(:populate_article_metadata)
      expect(result).to eq(mock_article)
    end
  end

  describe '#is_pubmed?' do
    let(:pubmed_doc) { double('doc', name: 'PubmedArticle') }
    let(:pmc_doc) { double('doc', name: 'article') }

    it 'returns true for PubMed documents' do
      result = service.send(:is_pubmed?, pubmed_doc)
      expect(result).to be true
    end

    it 'returns false for PMC documents' do
      result = service.send(:is_pubmed?, pmc_doc)
      expect(result).to be false
    end
  end

  describe '#attribute_builder' do
    let(:pubmed_doc) { double('doc', name: 'PubmedArticle') }
    let(:pmc_doc) { double('doc', name: 'article') }
    let(:mock_article) { double('article') }
    let(:mock_pubmed_builder) { double('pubmed_builder') }
    let(:mock_pmc_builder) { double('pmc_builder') }

    before do
      allow(Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PubmedAttributeBuilder)
        .to receive(:new).and_return(mock_pubmed_builder)
      allow(Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PmcAttributeBuilder)
        .to receive(:new).and_return(mock_pmc_builder)
    end

    it 'returns PubMed builder for PubMed documents' do
      result = service.send(:attribute_builder, pubmed_doc, mock_article)

      expect(Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PubmedAttributeBuilder)
        .to have_received(:new).with(pubmed_doc, mock_article, mock_admin_set, 'test_user')
      expect(result).to eq(mock_pubmed_builder)
    end

    it 'returns PMC builder for PMC documents' do
      result = service.send(:attribute_builder, pmc_doc, mock_article)

      expect(Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PmcAttributeBuilder)
        .to have_received(:new).with(pmc_doc, mock_article, mock_admin_set, 'test_user')
      expect(result).to eq(mock_pmc_builder)
    end
  end

  describe '#record_result' do
    let(:mock_article) { double('article', id: 'article_123') }
    let(:ids) { { 'pmid' => '123456', 'pmcid' => 'PMC789012' } }

    before do
      allow(Time).to receive(:now).and_return(Time.parse('2024-01-01 12:00:00 UTC'))
      allow(service).to receive(:flush_buffer_if_needed)
    end

    it 'adds entry to write buffer with correct format' do
      service.send(:record_result,
        category: :successfully_ingested,
        message: 'Success',
        ids: ids,
        article: mock_article
      )

      buffer = service.instance_variable_get(:@write_buffer)
      expect(buffer.size).to eq(1)

      entry = buffer.first
      expect(entry[:ids][:pmid]).to eq('123456')
      expect(entry[:ids][:pmcid]).to eq('PMC789012')
      expect(entry[:ids][:work_id]).to eq('article_123')
      expect(entry[:category]).to eq(:successfully_ingested)
      expect(entry[:message]).to eq('Success')
      expect(entry[:timestamp]).to eq('2024-01-01T12:00:00Z')
    end
  end

  describe '#flush_buffer_to_file' do
    let(:mock_file) { double('file') }
    let(:buffer_entries) do
      [
        { ids: { pmid: '123' }, category: :success },
        { ids: { pmid: '456' }, category: :failed }
      ]
    end

    before do
      service.instance_variable_set(:@write_buffer, buffer_entries.dup)
      allow(File).to receive(:open).with(results_path, 'a').and_yield(mock_file)
      allow(mock_file).to receive(:puts)
    end

    it 'writes buffer entries to file and clears buffer' do
      service.send(:flush_buffer_to_file)

      expect(mock_file).to have_received(:puts).with(buffer_entries[0].to_json)
      expect(mock_file).to have_received(:puts).with(buffer_entries[1].to_json)
      expect(service.instance_variable_get(:@write_buffer)).to be_empty
    end

    context 'when file write fails' do
      before do
        allow(File).to receive(:open).and_raise(StandardError.new('Write failed'))
      end

      it 'logs error' do
        service.send(:flush_buffer_to_file)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Failed to flush buffer to file: Write failed',
          :error,
          tag: 'MetadataIngestService'
        )
      end
    end
  end

  describe '#find_best_work_match' do
    let(:alternate_ids) { { pmid: '123456', pmcid: 'PMC789012', doi: '10.1000/example' } }

    context 'when DOI matches existing work' do
      let(:work_data) { { work_id: 'work_123', work_type: 'Article' } }

      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
          .with('10.1000/example').and_return(work_data)
      end

      it 'returns work data for DOI match' do
        result = service.send(:find_best_work_match, alternate_ids)
        expect(result).to eq(work_data)
      end
    end

    context 'when PMCID matches existing work' do
      let(:work_data) { { work_id: 'work_456', work_type: 'Article' } }

      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
          .with('10.1000/example').and_return(nil)
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
          .with('PMC789012').and_return(work_data)
      end

      it 'returns work data for PMCID match' do
        result = service.send(:find_best_work_match, alternate_ids)
        expect(result).to eq(work_data)
      end
    end

    context 'when no matches found' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      end

      it 'returns nil' do
        result = service.send(:find_best_work_match, alternate_ids)
        expect(result).to be_nil
      end
    end
  end

  describe '#save_results_json' do
    let(:test_path) { '/tmp/test_results.json' }
    let(:mock_file) { double('file') }

    before do
      allow(File).to receive(:open).with(test_path, 'w').and_yield(mock_file)
      allow(mock_file).to receive(:puts)
    end

    it 'writes results as pretty JSON' do
      service.send(:save_results_json, path: test_path)

      expect(mock_file).to have_received(:puts).with(JSON.pretty_generate(results))
      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Results JSON updated successfully.',
        :info,
        tag: 'MetadataIngestService'
      )
    end

    context 'when file write fails' do
      before do
        allow(File).to receive(:open).and_raise(StandardError.new('Write failed'))
      end

      it 'logs error' do
        service.send(:save_results_json, path: test_path)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Failed to update results JSON: Write failed',
          :error,
          tag: 'MetadataIngestService'
        )
      end
    end
  end

  describe '#generate_filtered_batch (pubmed)' do
    let(:pubmed_doc) do
      Nokogiri::XML(<<~XML)
        <PubmedArticleSet>
          <PubmedArticle>
            <MedlineCitation>
              <Article>
                <AuthorList>
                  <Author>
                    <AffiliationInfo>
                      <Affiliation>UNC Chapel Hill</Affiliation>
                    </AffiliationInfo>
                  </Author>
                </AuthorList>
              </Article>
            </MedlineCitation>
            <PubmedData>
              <ArticleIdList>
                <ArticleId IdType="pubmed">111111</ArticleId>
                <!-- optional -->
                <ArticleId IdType="doi">10.1000/example-111111</ArticleId>
              </ArticleIdList>
            </PubmedData>
          </PubmedArticle>
          <PubmedArticle>
            <MedlineCitation>
              <Article>
                <AuthorList>
                  <Author>
                    <AffiliationInfo>
                      <Affiliation>University of Nimes</Affiliation>
                    </AffiliationInfo>
                  </Author>
                </AuthorList>
              </Article>
            </MedlineCitation>
          </PubmedArticle>
          <PubmedArticle>
            <MedlineCitation>
              <Article>
                <AuthorList>
                  <Author>
                    <AffiliationInfo>
                      <Affiliation>   </Affiliation>
                    </AffiliationInfo>
                  </Author>
                </AuthorList>
              </Article>
            </MedlineCitation>
          </PubmedArticle>
        </PubmedArticleSet>
      XML
    end

    it 'keeps only UNC-affiliated docs and logs the skip count' do
      batch = pubmed_doc.xpath('//PubmedArticle')
      keep  = service.send(:generate_filtered_batch, batch, db: 'pubmed')
      kept  = keep.is_a?(Nokogiri::XML::NodeSet) ? keep.to_a : Array(keep)

      expect(kept.length).to eq(1)
      expect(kept.first.at_xpath('.//Affiliation').text).to match(/UNC/i)

      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_matching(/Filtered out 2 pubmed records with no UNC affiliation; 1 remain/),
        :info,
        tag: 'MetadataIngestService'
      )
    end

  end

end
