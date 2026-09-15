# frozen_string_literal: true
class MastersPapersController < ApplicationController

  before_action :authenticate_user!

  layout 'hyrax/dashboard'

  def department
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb I18n.t('hyrax.dashboard.my.works'), hyrax.my_works_path
    add_breadcrumb 'Add New Work', request.path
  end

  def select_department
    redirect_to new_hyrax_masters_paper_path(masters_papers_params)
  end

  private

  def masters_papers_params
    # Department selection can arrive as either a single value or an array
    # (the form select is configured with multiple), so permit both.
    permitted = params.require(:masters_paper).permit(:add_works_to_collection, :affiliation, affiliation: [])

    # Normalize to one non-blank affiliation for the redirect query string.
    affiliation = Array(permitted[:affiliation]).compact_blank.first

    {
      affiliation: affiliation,
      add_works_to_collection: permitted[:add_works_to_collection]
    }.compact_blank
  end
end
