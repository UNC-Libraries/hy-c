class MastersPapersController < ApplicationController

  layout 'dashboard'

  def department
  end

  def select_department
    redirect_to new_hyrax_masters_paper_path(masters_papers_params)
  end

  private
    def masters_papers_params
      params.require(:masters_paper).permit(:affiliation)
    end
end
