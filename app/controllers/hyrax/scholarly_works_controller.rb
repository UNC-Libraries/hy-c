# Generated via
#  `rails generate hyrax:work ScholarlyWork`

module Hyrax
  class ScholarlyWorksController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::ScholarlyWork

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::ScholarlyWorkPresenter
  end
end
