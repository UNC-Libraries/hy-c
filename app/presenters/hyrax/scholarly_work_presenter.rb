# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkPresenter < Hyrax::WorkShowPresenter
    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
