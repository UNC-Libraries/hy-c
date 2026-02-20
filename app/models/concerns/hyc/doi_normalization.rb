# frozen_string_literal: true
module Hyc
  module DoiNormalization
    extend ActiveSupport::Concern

    included do
      before_save :normalize_doi_field
    end

  private

    def normalize_doi_field
      return unless doi.present?

      normalized = WorkUtilsHelper.normalize_doi_to_canonical(doi) || doi

      self.doi = normalized if normalized != doi
    end
  end
end
