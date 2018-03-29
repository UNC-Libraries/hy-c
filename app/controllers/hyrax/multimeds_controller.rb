# Generated via
#  `rails generate hyrax:work Multimed`

module Hyrax
  class MultimedsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::Multimed

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::MultimedPresenter

    before_action :ensure_admin!, only: :destroy

    private
    def ensure_admin!
      authorize! :read, :admin_dashboard
    end
  end
end
