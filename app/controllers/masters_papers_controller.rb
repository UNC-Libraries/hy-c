class MastersPapersController < ApplicationController

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
      params.require(:masters_paper).permit(:affiliation, :add_works_to_collection).reject{|_, v| v.blank?}
    end
end
