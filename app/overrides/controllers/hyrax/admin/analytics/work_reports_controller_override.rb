# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/hyrax/admin/analytics/work_reports_controller.rb
require 'benchmark'

Hyrax::Admin::Analytics::WorkReportsController.class_eval do
  def index
    return unless Hyrax.config.analytics? && Hyrax.config.analytics_provider != 'ga4'

    time = Benchmark.measure do
      @accessible_works ||= accessible_works
    end
    Rails.logger.info("===accessible_works: #{time.real}")
    time = Benchmark.measure do
      @accessible_file_sets ||= accessible_file_sets
    end
    Rails.logger.info("===accessible_file_sets: #{time.real}")
    time = Benchmark.measure do
      @works_count = @accessible_works.count
    end
    Rails.logger.info("===accessible_works.count: #{time.real}")
    time = Benchmark.measure do
      @top_works = paginate(top_works_list, rows: 10)
    end
    Rails.logger.info("===top works: #{time.real}")
    time = Benchmark.measure do
      @top_file_set_downloads = paginate(top_files_list, rows: 10)
    end
    Rails.logger.info("===top download: #{time.real}")

    if current_user.ability.admin?
      time = Benchmark.measure do
        # [hyc-override] Use monthly stats instead of daily
        @pageviews = Hyrax::Analytics.monthly_events('work-view')
      end
      Rails.logger.info("===Total work page views: #{time.real}")
      time = Benchmark.measure do
        # [hyc-override] Use monthly stats instead of daily
        @downloads = Hyrax::Analytics.monthly_events('file-set-download')
      end
      Rails.logger.info("===Total downloads: #{time.real}")
    end

    respond_to do |format|
      format.html
      format.csv { export_data }
    end
  end

  # [hyc-override] Switch to monthly stats and fix typo in file-set-in-work-download
  def show
    @pageviews = Hyrax::Analytics.monthly_events_for_id(@document.id, 'work-view')
    @uniques = Hyrax::Analytics.unique_visitors_for_id(@document.id)
    @downloads = Hyrax::Analytics.monthly_events_for_id(@document.id, 'file-set-in-work-download')
    @files = paginate(@document._source['file_set_ids_ssim'], rows: 5)
    respond_to do |format|
      format.html
      format.csv { export_data }
    end
  end

  private
  # [hyc-override] Builds a hash instead of an array for faster lookups
  def top_analytics_works
    time = Benchmark.measure do
      @top_analytics_works_hash ||= convert_top_events_to_hash(Hyrax::Analytics.top_events('work-view', date_range))
    end
    Rails.logger.info("===top_analytics_works: #{time.real}")
    @top_analytics_works_hash
  end

  # [hyc-override] Builds a hash instead of an array for faster lookups
  def top_analytics_downloads
    time = Benchmark.measure do
      @top_analytics_downloads_hash ||= convert_top_events_to_hash(Hyrax::Analytics.top_events('file-set-in-work-download', date_range))
    end
    Rails.logger.info("===top_analytics_downloads: #{time.real}")
    @top_analytics_downloads_hash
  end

  # [hyc-override] Builds a hash instead of an array for faster lookups
  def top_analytics_file_sets
    time = Benchmark.measure do
      @top_analytics_file_sets_hash ||= convert_top_events_to_hash(Hyrax::Analytics.top_events('file-set-download', date_range))
    end
    Rails.logger.info("===top_analytics_file_sets: #{time.real}")
    @top_analytics_file_sets_hash
  end

  def convert_top_events_to_hash(top_events)
    top_events.each_with_object(Hash.new(0)) do |(id, count), hash|
      hash[id] += count
    end
  end

  # [hyc-override] Refactored to use hashes for faster lookups
  def top_works_list
    list = []
    top_analytics_works
    top_analytics_downloads
    @accessible_works.each do |doc|
      id = doc['id']
      views_match = @top_analytics_works_hash[id]
      downloads_match = @top_analytics_downloads_hash[id]
      list.push([doc['id'], doc['title_tesim'].join(''), views_match, downloads_match, doc['member_of_collections']])
    end
    list.sort_by { |l| -l[2] }
  end

  # [hyc-override] Refactored to use hashes for faster lookups
  def top_files_list
    list = []
    top_analytics_file_sets
    @accessible_file_sets.each do |doc|
      downloads_match = @top_analytics_file_sets_hash[doc['id']]
      list.push([doc['id'], doc['title_tesim'].join(''), downloads_match]) if doc['title_tesim'].present?
    end
    list.sort_by { |l| -l[2] }
  end
end
