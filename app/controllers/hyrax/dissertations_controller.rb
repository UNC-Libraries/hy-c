# Generated via
#  `rails generate hyrax:work Dissertation`

module Hyrax
  class DissertationsController < ApplicationController
    self.curation_concern_type = ::Dissertation

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::DissertationPresenter

    before_action :ensure_admin!, only: [:destroy, :create, :update, :edit, :new]
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]
  end
end
