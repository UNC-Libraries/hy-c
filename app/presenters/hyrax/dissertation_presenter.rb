# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
