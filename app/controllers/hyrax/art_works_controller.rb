# Generated via
#  `rails generate hyrax:work ArtWork`
module Hyrax
  # Generated controller for ArtWork
  class ArtWorksController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::ArtWork

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::ArtWorkPresenter

    before_action :ensure_admin!, only: :destroy
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]

    private
    def ensure_admin!
      authorize! :read, :admin_dashboard
    end

    def ensure_admin_set!
      if AdminSet.all.count == 0
        return redirect_to root_path, alert: 'No Admin Sets have been created.'
      end
    end
  end
end
