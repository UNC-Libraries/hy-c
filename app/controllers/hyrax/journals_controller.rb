# Generated via
#  `rails generate hyrax:work Journal`

module Hyrax
  class JournalsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::Journal

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::JournalPresenter
  end
end
