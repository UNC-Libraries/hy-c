# Generated via
#  `rails generate hyrax:work Article`

module Hyrax
  class ArticlesController < HycController
    self.curation_concern_type = ::Article

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::ArticlePresenter

    before_action :ensure_admin!, only: :destroy
    before_action :ensure_admin_set!, only: [:create, :new, :edit, :update]
  end
end
