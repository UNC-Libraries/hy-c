# Generated via
#  `rails generate hyrax:work Article`

module Hyrax
  class ArticlesController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::Article

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::ArticlePresenter

    before_action :ensure_admin!, only: :destroy

    private
    def ensure_admin!
      authorize! :read, :admin_dashboard
    end
  end
end
