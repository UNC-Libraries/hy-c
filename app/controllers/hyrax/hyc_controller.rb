module Hyrax
  class HycController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks

    private

    def ensure_admin!
      authorize! :read, :admin_dashboard
    end

    def ensure_admin_set!
      return redirect_to root_path, alert: 'No Admin Sets have been created.' if AdminSet.all.count.zero?
    end
  end
end
