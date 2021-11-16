class DefaultAdminSetsController < ApplicationController
  before_action :set_default_admin_set, only: [:edit, :update, :destroy]
  before_action :create_default_records, only: [:edit, :new]
  before_action :set_admin_sets, :set_work_types, only: [:edit, :new, :create, :update]
  before_action :ensure_admin!

  layout 'hyrax/dashboard'

  def index
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Admin Set Worktypes', request.path
    if AdminSet.all.count == 0
      @default_admin_sets = nil
    else
      create_default_records
      @default_admin_sets = DefaultAdminSet.all
    end
  end

  def new
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Admin Set Worktypes', main_app.default_admin_sets_path
    add_breadcrumb 'New Admin Set Worktype', request.path
    @default_admin_set = DefaultAdminSet.new
  end

  def edit
    add_breadcrumb t(:'hyrax.controls.home'), root_path
    add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
    add_breadcrumb 'Admin Set Worktypes', main_app.default_admin_sets_path
    add_breadcrumb 'Edit Admin Set Worktype', request.path
  end

  def create
    @default_admin_set = DefaultAdminSet.new(default_admin_set_params)

    respond_to do |format|
      if @default_admin_set.save
        format.html { redirect_to default_admin_sets_path, notice: 'Admin set worktype was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  def update
    respond_to do |format|
      if @default_admin_set.update(default_admin_set_params)
        format.html { redirect_to default_admin_sets_path, notice: 'Admin set worktype was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    @default_admin_set.destroy
    respond_to do |format|
      format.html { redirect_to default_admin_sets_url, notice: 'Admin set worktype set was successfully deleted.' }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_default_admin_set
    @default_admin_set = DefaultAdminSet.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def default_admin_set_params
    params.require(:default_admin_set).permit(:work_type_name, :admin_set_id, :department)
  end

  def ensure_admin!
    authorize! :read, :admin_dashboard
  end

  def set_admin_sets
    @admin_sets = AdminSet.all.map { |admin_set| [admin_set.title.first, admin_set.id] }
  end

  def set_work_types
    # Get list of all work types available to an admin
    work_type_presenter = Hyrax::SelectTypeListPresenter.new(current_ability.current_user)
    model_list = work_type_presenter.authorized_models
    model_list.map! { |i| i.to_s }
    @work_type_names = model_list
  end

  def create_default_records
    # Get list of saved work type/admin set pairings
    work_types = DefaultAdminSet.all.order(:id).to_a

    # Get list of all work types available to an admin
    work_type_presenter = Hyrax::SelectTypeListPresenter.new(current_ability.current_user)
    model_list = work_type_presenter.authorized_models
    model_list.map! { |i| i.to_s }
    @work_type_names = model_list

    # Make sure all available work types have a default admin set
    work_types.each do |i|
      model_list.delete(i.work_type_name)
    end

    # Create new records for work types with no default admin set
    unless model_list.blank?
      default_admin_set_id = AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).first.id
      model_list.each do |i|
        DefaultAdminSet.create(work_type_name: i, admin_set_id: default_admin_set_id)
      end
    end
  end
end
