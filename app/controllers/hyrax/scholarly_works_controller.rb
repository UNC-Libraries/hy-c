# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work ScholarlyWork`

module Hyrax
  class ScholarlyWorksController < HycController
    self.curation_concern_type = ::ScholarlyWork

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::ScholarlyWorkPresenter

    before_action :ensure_admin!, only: :destroy
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]
  end
end
