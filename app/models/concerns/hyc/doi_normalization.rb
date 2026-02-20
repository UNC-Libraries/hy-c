# frozen_string_literal: true
module Hyc
  module DoiNormalization
    extend ActiveSupport::Concern

    included do
      before_save :normalize_doi_field
    end

    private

    def normalize_doi_field
      normalized = WorkUtilsHelper.normalize_doi_to_canonical(doi)

      # Set to nil if normalization fails (invalid format) or if empty string
      normalized = nil if normalized.blank?

      self.doi = normalized if normalized != doi
    end
  end
end
