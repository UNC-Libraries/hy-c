# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work HonorsThesis`

module Hyrax
  class HonorsThesesController < HycController
    self.curation_concern_type = ::HonorsThesis

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::HonorsThesisPresenter

    before_action :ensure_admin!, only: :destroy
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]
  end
end
