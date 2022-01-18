module Hyrax
  class UnrestrictedClassificationQuery < Hyrax::QuickClassificationQuery
    # @return [Array] a list of all the requested concerns
    def authorized_models
      normalized_model_names.select
    end
  end
end
