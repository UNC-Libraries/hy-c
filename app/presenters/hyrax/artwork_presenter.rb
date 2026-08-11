# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Artwork`
module Hyrax
  class ArtworkPresenter < Hyrax::WorkShowPresenter
    include EmbargoHistoryPresenter
  end
end
