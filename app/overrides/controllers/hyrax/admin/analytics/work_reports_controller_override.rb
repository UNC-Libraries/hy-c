# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/admin/analytics/work_reports_controller.rb
require 'benchmark'

Hyrax::Admin::Analytics::WorkReportsController.class_eval do
  def index
    return unless Hyrax.config.analytics? && Hyrax.config.analytics_provider != 'ga4'

    time = Benchmark.measure do
      @accessible_works ||= accessible_works
    end
    Rails.logger.error("===accessible_works: #{time.real}")
    time = Benchmark.measure do
      @accessible_file_sets ||= accessible_file_sets
    end
    Rails.logger.error("===accessible_file_sets: #{time.real}")
    time = Benchmark.measure do
      @works_count = @accessible_works.count
    end
    Rails.logger.error("===accessible_works.count: #{time.real}")
    time = Benchmark.measure do
      @top_works = paginate(top_works_list, rows: 10)
    end
    Rails.logger.error("===top works: #{time.real}")
    time = Benchmark.measure do
      @top_file_set_downloads = paginate(top_files_list, rows: 10)
    end
    Rails.logger.error("===top download: #{time.real}")

    if current_user.ability.admin?
      time = Benchmark.measure do
        # [hyc-override] Use monthly stats instead of daily
        @pageviews = Hyrax::Analytics.monthly_events('work-view')
      end
      Rails.logger.error("===Total work page views: #{time.real}")
      time = Benchmark.measure do
        # [hyc-override] Use monthly stats instead of daily
        @downloads = Hyrax::Analytics.monthly_events('file-set-download')
      end
      Rails.logger.error("===Total downloads: #{time.real}")
    end

    respond_to do |format|
      format.html
      format.csv { export_data }
    end
  end

  private
  def top_analytics_works
    time = Benchmark.measure do
      @top_analytics_works ||= Hyrax::Analytics.top_events('work-view', date_range)
    end
    Rails.logger.error("===top_analytics_works: #{time.real}")
    @top_analytics_works
  end

  def top_analytics_downloads
    time = Benchmark.measure do
      @top_analytics_downloads ||= Hyrax::Analytics.top_events('file-set-in-work-download', date_range)
    end
    Rails.logger.error("===top_analytics_downloads: #{time.real}")
    @top_analytics_downloads
  end

  def top_analytics_file_sets
    time = Benchmark.measure do
      @top_analytics_file_sets ||= Hyrax::Analytics.top_events('file-set-download', date_range)
    end
    Rails.logger.error("===top_analytics_file_sets: #{time.real}")
    @top_analytics_file_sets
  end

  # [hyc-override] no changes yet
  def top_works_list
    list = []
    top_analytics_works
    top_analytics_downloads
    @accessible_works.each do |doc|
      views_match = @top_analytics_works.detect { |id, _count| id == doc['id'] }
      @view_count = views_match ? views_match[1] : 0
      downloads_match = @top_analytics_downloads.detect { |id, _count| id == doc['id'] }
      @download_count = downloads_match ? downloads_match[1] : 0
      list.push([doc['id'], doc['title_tesim'].join(''), @view_count, @download_count, doc['member_of_collections']])
    end
    list.sort_by { |l| -l[2] }
  end

  # [hyc-override] no changes yet
  def top_files_list
    list = []
    top_analytics_file_sets
    @accessible_file_sets.each do |doc|
      downloads_match = @top_analytics_file_sets.detect { |id, _count| id == doc['id'] }
      @download_count = downloads_match ? downloads_match[1] : 0
      list.push([doc['id'], doc['title_tesim'].join(''), @download_count]) if doc['title_tesim'].present?
    end
    list.sort_by { |l| -l[2] }
  end
end
