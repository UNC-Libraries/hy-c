# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
