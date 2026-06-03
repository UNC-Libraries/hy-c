# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalPresenter < Hyrax::WorkShowPresenter
    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
