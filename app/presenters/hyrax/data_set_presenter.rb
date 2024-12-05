# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    include Hyrax::SharedDelegates
    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
