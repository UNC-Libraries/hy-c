# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work General`

module Hyrax
  class GeneralsController < HycController
    self.curation_concern_type = ::General

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::GeneralPresenter

    before_action :ensure_admin!, only: [:destroy, :create, :update, :edit, :new]
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]
  end
end
