# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/controllers/hyrax/admin/analytics/work_reports_controller.rb
Hyrax::Admin::Analytics::WorkReportsController.class_eval do
  def index
    # [hyc-override] Only show analytics to logged in users
    return unless Hyrax.config.analytics? && Hyrax.config.analytics_provider != 'ga4' && current_user

    @accessible_works ||= accessible_works
    @accessible_file_sets ||= accessible_file_sets
    @works_count = @accessible_works.count
    @top_works = paginate(top_works_list, rows: 10)
    @top_file_set_downloads = paginate(top_files_list, rows: 10)

    if current_user.ability.admin?
      @pageviews = Hyrax::Analytics.daily_events('work-view')
      @downloads = Hyrax::Analytics.daily_events('file-set-download')
    end

    respond_to do |format|
      format.html
      format.csv { export_data }
    end
  end
end
