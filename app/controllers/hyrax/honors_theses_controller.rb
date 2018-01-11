# Generated via
#  `rails generate hyrax:work HonorsThesis`

module Hyrax
  class HonorsThesesController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::HonorsThesis

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::HonorsThesisPresenter
  end
end
