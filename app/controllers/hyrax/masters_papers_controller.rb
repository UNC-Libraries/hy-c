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

    before_action :ensure_admin!, only: :destroy
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]

    private
    def ensure_admin!
      authorize! :read, :admin_dashboard
    end

    def ensure_admin_set!
      return redirect_to root_path, alert: 'No Admin Sets have been created.' if AdminSet.all.count.zero?
    end
  end
end
