# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedPresenter < Hyrax::WorkShowPresenter
    include EmbargoHistoryPresenter
  end
end
