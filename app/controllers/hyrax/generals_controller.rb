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

    before_action :ensure_admin!, only: :destroy

    private
    def ensure_admin!
      authorize! :read, :admin_dashboard
    end
  end
end
