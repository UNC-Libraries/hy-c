# Generated via
#  `rails generate hyrax:work MastersPaper`

module Hyrax
  class MastersPapersController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::MastersPaper

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::MastersPaperPresenter
  end
end
