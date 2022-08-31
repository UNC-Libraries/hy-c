# frozen_string_literal: true
module Hyc
  module FileSetBehavior
    extend ActiveSupport::Concern
    include Hyrax::FileSetBehavior

    included do
      before_destroy :deregister_longleaf
    end

    def deregister_longleaf
      Rails.logger.info("Calling deregistration from longleaf after delete of #{original_file}")
      DeregisterLongleafJob.perform_later(self)
    end
  end
end
