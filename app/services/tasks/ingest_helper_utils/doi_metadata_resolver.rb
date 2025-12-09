# frozen_string_literal: true
module Tasks::IngestHelperUtils
    class DoiMetadataResolver
      include Tasks::NsfIngest::Backlog::Utilities::MetadataRetrievalHelper

      attr_reader :doi, :admin_set, :depositor_onyen

      def initialize(doi:, admin_set:, depositor_onyen:)
        @doi = doi
        @admin_set = admin_set
        @depositor_onyen = depositor_onyen
      end

      # Main method - does everything and returns the attribute builder
      def resolve_and_build
        fetch_all_metadata
        verify_source_available
        merge_sources
        construct_attribute_builder
      end

      # Individual steps exposed if you need them
      def fetch_all_metadata
        @crossref_md = fetch_metadata_for_doi(source: 'crossref', doi: doi)
        @openalex_md = fetch_metadata_for_doi(source: 'openalex', doi: doi)
        @datacite_md = fetch_metadata_for_doi(source: 'datacite', doi: doi)
      end

      def verify_source_available
        return if @crossref_md && @openalex_md

        if @crossref_md.nil? && @openalex_md.nil?
          raise "No metadata found from Crossref or OpenAlex for DOI #{doi}."
        end

        missing_source = @crossref_md.nil? ? 'Crossref' : 'OpenAlex'
        chosen_source  = @crossref_md.nil? ? 'OpenAlex' : 'Crossref'
        LogUtilsHelper.double_log(
          "No metadata found from #{missing_source} for DOI #{doi}. Using #{chosen_source} metadata.",
          :warn,
          tag: 'MetadataResolver'
        )
      end

      def merge_sources
        # Default to OpenAlex metadata if available else Crossref
        @resolved_md = @openalex_md || @crossref_md
        @resolved_md['source'] = @openalex_md.present? ? 'openalex' : 'crossref'
        @resolved_md['openalex_abstract'] = generate_openalex_abstract(@openalex_md)
        @resolved_md['datacite_abstract'] = @datacite_md.dig('attributes', 'description') if @datacite_md&.dig('attributes', 'description').present?
        @resolved_md['openalex_keywords'] = extract_keywords_from_openalex(@openalex_md)
        @resolved_md
      end

      def construct_attribute_builder
        case @resolved_md['source']
        when 'openalex'
          Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::OpenalexAttributeBuilder.new(
            @resolved_md,
            admin_set,
            depositor_onyen
          )
        when 'crossref'
          Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::CrossrefAttributeBuilder.new(
            @resolved_md,
            admin_set,
            depositor_onyen
          )
        end
      end

      # Access to the resolved metadata if needed
      def resolved_metadata
        @resolved_md
      end
    end
end
