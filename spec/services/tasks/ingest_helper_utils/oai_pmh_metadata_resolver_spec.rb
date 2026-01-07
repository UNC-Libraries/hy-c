# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::OaiPmhMetadataResolver do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor_onyen) { 'testuser' }
  let(:full_text_dir) { Rails.root.join('spec/fixtures/files/oai_pmh_records') }
  let(:record_id) { '140512' }
  let(:identifier_key_name) { 'cdc_id' }

  let(:resolver) do
    described_class.new(
      id: record_id,
      identifier_key_name: identifier_key_name,
      full_text_dir: full_text_dir,
      admin_set: admin_set,
      depositor_onyen: depositor_onyen
    )
  end

  let(:sample_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
        <GetRecord>
          <record>
            <header>
              <identifier>oai:cdc.stacks:cdc:140512</identifier>
              <datestamp>2024-01-08T16:35:20Z</datestamp>
            </header>
            <metadata>
              <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
                         xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>2023 year in review : Preventing chronic disease</dc:title>
                <dc:description>Preventing Chronic Disease (PCD) is pleased to release its 2023 Year in Review.</dc:description>
                <dc:description>2023</dc:description>
                <dc:contributor>Centers for Disease Control and Prevention (U.S.)</dc:contributor>
              </oai_dc:dc>
            </metadata>
          </record>
        </GetRecord>
      </OAI-PMH>
    XML
  end

  before do
    FileUtils.mkdir_p(File.join(full_text_dir, record_id))
    File.write(resolver.metadata_path, sample_xml)
  end

  after do
    FileUtils.rm_rf(File.join(full_text_dir, record_id))
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(resolver.id).to eq(record_id)
      expect(resolver.admin_set).to eq(admin_set)
      expect(resolver.depositor_onyen).to eq(depositor_onyen)
      expect(resolver.metadata_path).to eq(File.join(full_text_dir, record_id, 'oai_pmh_metadata.xml'))
      expect(resolver.resolved_metadata).to eq({})
    end
  end

  describe '#parse_metadata_from_xml' do
    it 'extracts title from XML' do
      resolver.parse_metadata_from_xml
      expect(resolver.resolved_metadata['title']).to eq('2023 year in review : Preventing chronic disease')
    end

    it 'attaches the ID to metadata using the identifier key name' do
      resolver.parse_metadata_from_xml
      expect(resolver.resolved_metadata['cdc_id']).to eq(record_id)
    end

    it 'extracts contributors as authors' do
      resolver.parse_metadata_from_xml
      authors = resolver.resolved_metadata['authors']
      expect(authors).to be_an(Array)
      expect(authors.first['name']).to eq('Centers for Disease Control and Prevention (U.S.)')
      expect(authors.first['index']).to eq('0')
    end

    it 'uses UNC as default author when no contributors exist' do
      xml_without_contributors = sample_xml.gsub(/<dc:contributor>.*?<\/dc:contributor>/, '')
      File.write(resolver.metadata_path, xml_without_contributors)

      resolver.parse_metadata_from_xml
      authors = resolver.resolved_metadata['authors']
      expect(authors).to eq([{ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }])
    end

    it 'extracts the best abstract from multiple descriptions' do
      resolver.parse_metadata_from_xml
      expect(resolver.resolved_metadata['abstract']).to eq('Preventing Chronic Disease (PCD) is pleased to release its 2023 Year in Review.')
    end

    it 'extracts date from year-only description' do
      resolver.parse_metadata_from_xml
      expect(resolver.resolved_metadata['date_issued']).to eq('2023-01-01')
    end

    context 'with date in M/D/YYYY format' do
      let(:xml_with_mdy_date) do
        sample_xml.gsub('<dc:description>2023</dc:description>', '<dc:description>4/20/2018</dc:description>')
      end

      it 'normalizes M/D/YYYY to YYYY-MM-DD' do
        File.write(resolver.metadata_path, xml_with_mdy_date)
        resolver.parse_metadata_from_xml
        expect(resolver.resolved_metadata['date_issued']).to eq('2018-04-20')
      end
    end

    context 'with date in MM/DD/YYYY format' do
      let(:xml_with_mmddyyyy) do
        sample_xml.gsub('<dc:description>2023</dc:description>', '<dc:description>12/25/2020</dc:description>')
      end

      it 'normalizes MM/DD/YYYY to YYYY-MM-DD' do
        File.write(resolver.metadata_path, xml_with_mmddyyyy)
        resolver.parse_metadata_from_xml
        expect(resolver.resolved_metadata['date_issued']).to eq('2020-12-25')
      end
    end

    context 'with YYYY-MM-DD format' do
      let(:xml_with_iso_date) do
        sample_xml.gsub('<dc:description>2023</dc:description>', '<dc:description>2022-03-15</dc:description>')
      end

      it 'uses YYYY-MM-DD as-is' do
        File.write(resolver.metadata_path, xml_with_iso_date)
        resolver.parse_metadata_from_xml
        expect(resolver.resolved_metadata['date_issued']).to eq('2022-03-15')
      end
    end

    context 'when no date in descriptions' do
      let(:xml_no_year) do
        sample_xml.gsub('<dc:description>2023</dc:description>', '')
      end

      it 'falls back to datestamp from header' do
        File.write(resolver.metadata_path, xml_no_year)
        resolver.parse_metadata_from_xml
        expect(resolver.resolved_metadata['date_issued']).to eq('2024-01-08')
      end
    end

    context 'when datestamp has timestamp' do
      let(:xml_with_timestamp) do
        sample_xml.gsub('<dc:description>2023</dc:description>', '')
      end

      it 'extracts just the date part from ISO timestamp' do
        File.write(resolver.metadata_path, xml_with_timestamp)
        resolver.parse_metadata_from_xml
        expect(resolver.resolved_metadata['date_issued']).to eq('2024-01-08')
      end
    end
  end

  describe '#extract_best_abstract' do
    it 'filters out year-only descriptions' do
      descriptions = ['2023', 'This is a real abstract with content.', '2020']
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to eq('This is a real abstract with content.')
    end

    it 'filters out numeric-only descriptions' do
      descriptions = ['12345', 'This is a real abstract.']
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to eq('This is a real abstract.')
    end

    it 'filters out email addresses' do
      descriptions = ['test@example.com', 'This is the actual abstract.']
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to eq('This is the actual abstract.')
    end

    it 'filters out date-only descriptions (M/D/YYYY)' do
      descriptions = ['4/20/2018', 'This is the real abstract.']
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to eq('This is the real abstract.')
    end

    it 'filters out descriptions with fewer than 5 words' do
      descriptions = ['Too short', 'This is a proper abstract with enough words.']
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to eq('This is a proper abstract with enough words.')
    end

    it 'returns the longest remaining description' do
      descriptions = [
        'Short abstract here.',
        'This is a much longer abstract with more detailed information about the topic.',
        'Medium length abstract.'
      ]
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to eq('This is a much longer abstract with more detailed information about the topic.')
    end

    it 'returns nil for empty array' do
      result = resolver.send(:extract_best_abstract, [])
      expect(result).to be_nil
    end

    it 'returns nil when all descriptions are filtered out' do
      descriptions = ['2023', '12345', 'test@example.com', 'short']
      result = resolver.send(:extract_best_abstract, descriptions)
      expect(result).to be_nil
    end
  end

  describe '#construct_attribute_builder' do
    before do
      resolver.parse_metadata_from_xml
    end

    it 'returns an OaiPmhAttributeBuilder instance' do
      builder = resolver.construct_attribute_builder
      expect(builder).to be_a(Tasks::IngestHelperUtils::SharedAttributeBuilders::OaiPmhAttributeBuilder)
    end

    it 'passes resolved metadata, admin_set, and depositor to builder' do
      builder = resolver.construct_attribute_builder
      expect(builder.metadata).to eq(resolver.resolved_metadata)
      expect(builder.admin_set).to eq(admin_set)
      expect(builder.depositor_onyen).to eq(depositor_onyen)
    end
  end

  describe '#resolve_and_build' do
    it 'parses metadata and returns attribute builder' do
      builder = resolver.resolve_and_build
      expect(builder).to be_a(Tasks::IngestHelperUtils::SharedAttributeBuilders::OaiPmhAttributeBuilder)
      expect(resolver.resolved_metadata['title']).to be_present
      expect(resolver.resolved_metadata['cdc_id']).to eq(record_id)
    end
  end

  describe 'edge cases' do
    it 'handles missing title gracefully' do
      xml_no_title = sample_xml.gsub(/<dc:title>.*?<\/dc:title>/, '')
      File.write(resolver.metadata_path, xml_no_title)

      resolver.parse_metadata_from_xml
      expect(resolver.resolved_metadata['title']).to be_nil
    end

    it 'handles missing descriptions gracefully' do
      xml_no_descriptions = sample_xml.gsub(/<dc:description>.*?<\/dc:description>/, '')
      File.write(resolver.metadata_path, xml_no_descriptions)

      resolver.parse_metadata_from_xml
      expect(resolver.resolved_metadata['abstract']).to be_nil
    end

    it 'handles completely empty XML metadata section' do
      xml_empty_metadata = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
          <GetRecord>
            <record>
              <header>
                <datestamp>2024-01-08T16:35:20Z</datestamp>
              </header>
              <metadata>
                <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
                </oai_dc:dc>
              </metadata>
            </record>
          </GetRecord>
        </OAI-PMH>
      XML

      File.write(resolver.metadata_path, xml_empty_metadata)
      resolver.parse_metadata_from_xml

      expect(resolver.resolved_metadata['title']).to be_nil
      expect(resolver.resolved_metadata['abstract']).to be_nil
      expect(resolver.resolved_metadata['date_issued']).to eq('2024-01-08')
      expect(resolver.resolved_metadata['authors']).to eq([{ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }])
    end
  end
end
