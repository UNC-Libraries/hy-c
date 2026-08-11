# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    include EmbargoHistoryPresenter

    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
