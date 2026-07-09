# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    include EmbargoHistoryPresenter

    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
