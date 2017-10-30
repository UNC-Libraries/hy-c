# Generated via
#  `rails generate hyrax:work OpenAccess`

module Hyrax
  class OpenAccessesController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::OpenAccess

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::OpenAccessPresenter
  end
end
