# frozen_string_literal: true
module Hyc
  module FileSetBehavior
    extend ActiveSupport::Concern
    include Hyrax::FileSetBehavior

    included do
      # Hyrax 5 switches derivative persistence to Valkyrie when FileSetBehavior
      # is included, but this Wings/ActiveFedora app still expects filesystem
      # thumbnails and directly contained extracted text.
      # See the following for info about issues with setting this with an initializer:
      # https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/models/concerns/hyrax/file_set/derivatives.rb
      Hydra::Derivatives.source_file_service = Hyrax::LocalFileService
      Hydra::Derivatives.output_file_service = Hyrax::PersistDerivatives
      Hydra::Derivatives::FullTextExtract.output_file_service = Hyrax::PersistDirectlyContainedOutputFileService

      before_destroy :deregister_longleaf
    end

    def deregister_longleaf
      return unless original_file.present?

      checksum = original_file.checksum.value
      Rails.logger.info("Calling deregistration from longleaf after delete of #{original_file} #{checksum}")
      DeregisterLongleafJob.perform_later(checksum)
    end
  end
end
