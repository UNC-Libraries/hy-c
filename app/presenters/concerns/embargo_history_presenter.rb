# app/presenters/concerns/embargo_history_presenter.rb
# frozen_string_literal: true

module EmbargoHistoryPresenter
  extend ActiveSupport::Concern

  def embargo_history
    solr_document['embargo_history_ssim'] || []
  end
end
