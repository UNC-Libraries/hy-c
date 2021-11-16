# Generated via
#  `rails generate hyrax:work DataSet`

module Hyrax
  class DataSetsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::DataSet

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::DataSetPresenter

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
