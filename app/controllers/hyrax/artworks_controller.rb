# Generated via
#  `rails generate hyrax:work Artwork`
module Hyrax
  # Generated controller for Artwork
  class ArtworksController < HycController
    self.curation_concern_type = ::Artwork

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::ArtworkPresenter

    before_action :ensure_admin!, only: :destroy
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]
  end
end
