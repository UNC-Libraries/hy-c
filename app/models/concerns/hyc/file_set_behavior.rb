# frozen_string_literal: true
module Hyc
  module FileSetBehavior
    extend ActiveSupport::Concern
    include Hyrax::FileSetBehavior

    included do
      before_destroy :deregister_longleaf
    end

    def deregister_longleaf
      checksum = original_file.checksum.value
      Rails.logger.info("Calling deregistration from longleaf after delete of #{original_file} #{checksum}")
      DeregisterLongleafJob.perform_later(checksum)
    end
  end
end
