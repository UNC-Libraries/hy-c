class WorkTypesController < ApplicationController
  before_action :set_work_types, only: [:edit, :index]
  before_action :set_admin_sets, only: :edit
  before_action :ensure_admin!

  layout 'dashboard'

  def index
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Work Types', request.path
  end

  def edit
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Work Types', main_app.work_types_path
    add_breadcrumb 'Edit', request.path
  end

  def update
    params['work_types'].each do |id, work_type|
      record = WorkType.where(work_type_name: work_type['work_type_name'])
      if record.blank?
        unless WorkType.create(work_type_name: work_type['work_type_name'], admin_set_id: work_type['admin_set_id'])
          redirect_to edit_work_types_path
        end
      else
        unless record.update(admin_set_id: work_type['admin_set_id'])
          redirect_to edit_work_types_path
        end
      end
    end

    redirect_to main_app.work_types_path
  end


  private
    def ensure_admin!
      authorize! :read, :admin_dashboard
    end

    def set_work_types
      # Get list of saved work type/admin set pairings
      @work_types = WorkType.all.order(:id).to_a

      # Get list of all work types available to an admin
      work_type_presenter = Hyrax::SelectTypeListPresenter.new(current_ability.current_user)
      model_list = work_type_presenter.authorized_models
      model_list.map! { |i| i.to_s }

      # Make sure all available work types have a default admin set
      @work_types.each do |i|
        model_list.delete(i.work_type_name)
      end

      # Create new records for work types with no default admin set
      unless model_list.blank?
        default_admin_set_id = AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first.id
        model_list.each do |i|
          @work_types << WorkType.create(work_type_name: i, admin_set_id: default_admin_set_id)
        end
      end
    end

    def set_admin_sets
      @admin_sets = AdminSet.all.map { |admin_set| [admin_set.title.first, admin_set.id]}
    end
end
