# Generated via
#  `rails generate hyrax:work General`

module Hyrax
  class GeneralsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::General

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::GeneralPresenter
  end
end
