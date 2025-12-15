# frozen_string_literal: true
# Fetches and resolves DOI metadata from OAI-PMH sources.
module Tasks::IngestHelperUtils
  class OaiPmhMetadataResolver
    include Tasks::IngestHelperUtils::OaiPmhMetadataRetrievalHelper

    attr_reader :cdc_id, :metadata_path, :admin_set, :depositor_onyen, :resolved_metadata

    def initialize(cdc_id:, full_text_dir:, admin_set:, depositor_onyen:)
      @cdc_id = cdc_id
      @metadata_path = File.join(full_text_dir, cdc_id, 'oai_pmh_metadata.xml')
      @admin_set = admin_set
      @depositor_onyen = depositor_onyen
      @resolved_metadata = {}
    end

    def resolve_and_build
      parse_metadata_from_xml
      construct_attribute_builder
    end

    def parse_metadata_from_xml
      xml_content = File.read(metadata_path)
      doc = Nokogiri::XML(xml_content)
      doc.remove_namespaces! # Simplifies XPath queries

      # Extract CDC ID from OAI identifier
      @resolved_metadata['cdc_id'] = @cdc_id

      # Extract title
      @resolved_metadata['title'] = extract_dc_field(doc, 'title')

      # Extract description/abstract (may be multiple, take first)
      descriptions = extract_dc_fields(doc, 'description')
      @resolved_metadata['abstract'] = descriptions.first if descriptions.any?

      @resolved_metadata['date_issued'] = extract_date(doc)

      contributors = extract_dc_fields(doc, 'contributor')
      @resolved_metadata['publisher'] = contributors&.first if contributors.any?
      @resolved_metadata['funders'] = contributors[1..] if contributors&.size.to_i > 1

      # Authors typically are not present in Stacks OAI-PMH records, stub with default
      @resolved_metadata['authors'] = [{
        'name' => 'The University of North Carolina at Chapel Hill',
        'index' => '0'
      }]

      @resolved_metadata
    end

    # Stubs
    def construct_attribute_builder
      # TODO: Implement
    end

    private

    def extract_dc_field(doc, field_name)
      node = doc.at_xpath("//dc:#{field_name}")
      node&.text&.strip
    end

    def extract_dc_fields(doc, field_name)
      nodes = doc.xpath("//dc:#{field_name}")
      nodes.map { |node| node.text.strip }.reject(&:empty?)
    end

    def extract_date(doc)
      descriptions = extract_dc_fields(doc, 'description')

      # Look for descriptions that are ONLY a year (and whitespace)
      descriptions.each do |desc|
        trimmed = desc.strip
        # Match if the entire description is just a 4-digit year
        if trimmed.match?(/\A(19|20)\d{2}\z/)
          return "#{trimmed}-01-01" # Normalize to YYYY-01-01
        end
      end

      # Look for date patterns like "4/20/2018" or "2018-03-15"
      descriptions.each do |desc|
        trimmed = desc.strip
        # Match M/D/YYYY or MM/DD/YYYY
        if (match = trimmed.match(%r{\A(\d{1,2})/(\d{1,2})/((?:19|20)\d{2})\z}))
          month = match[1].rjust(2, '0')
          day = match[2].rjust(2, '0')
          year = match[3]
          return "#{year}-#{month}-#{day}" # Normalize to YYYY-MM-DD
        end
        # Match YYYY-MM-DD (already normalized)
        if trimmed.match?(/\A((?:19|20)\d{2})-\d{2}-\d{2}\z/)
          return trimmed
        end
      end

      # Fallback to datestamp from header
      datestamp = doc.at_xpath('//header/datestamp')
      if datestamp
        timestamp = datestamp.text.strip
        # Extract just the date part (YYYY-MM-DD) from the ISO timestamp
        return timestamp.split('T').first if timestamp.include?('T')
        return timestamp
      end

      nil
    end
  end
end
