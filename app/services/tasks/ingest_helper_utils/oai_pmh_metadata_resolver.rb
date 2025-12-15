# frozen_string_literal: true
# Fetches and resolves DOI metadata from OAI-PMH sources.
module Tasks::IngestHelperUtils
  class OaiPmhMetadataResolver
    include Tasks::IngestHelperUtils::OaiPmhMetadataRetrievalHelper

    attr_reader :metadata_path, :admin_set, :depositor_onyen

    def initialize(metadata_path:, admin_set:, depositor_onyen:)
      @metadata_path = metadata_path
      @admin_set = admin_set
      @depositor_onyen = depositor_onyen
    end

    def resolve_and_build
      fetch_metadata_from_oai_pmh
      construct_attribute_builder
    end

    # Stubs
    def fetch_metadata_from_oai_pmh
        # TODO: Implement
    end
    def construct_attribute_builder
        # TODO: Implement
    end
  end
end
