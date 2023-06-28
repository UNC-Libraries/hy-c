# frozen_string_literal: true
module Tasks
  require 'tasks/migrate/services/progress_tracker'

  class StatsCacheUpdatingService
    WORK_TYPES = ['Article', 'Artwork', 'DataSet', 'Dissertation', 'General', 'HonorsThesis', 'Journal', 'MastersPaper',
                'Multimed', 'ScholarlyWork']
    REPORT_EVERY_N = 10

    attr_accessor :per_page

    def initialize
      @completed_ids = progress_tracker.completed_set
      @per_page = 1000
    end

    def update_all
      update_works
      update_file_sets
    end

    def update_works
      # List all objects by type to split up the result set
      WORK_TYPES.each do |obj_type|
        update_records(obj_type, Hyrax::WorkUsage)
      end
    end

    def update_file_sets
      update_records('FileSet', Hyrax::FileUsage)
    end

    def update_records(model_name, usage_class)
      total_entries = nil
      total_time = 0
      cnt = 0
      loop do
        resp = ActiveFedora::SolrService.get("has_model_ssim:#{model_name}", :rows => @per_page, :start => cnt)["response"]
        total_entries = resp['numFound'] if total_entries.nil?
        records = resp["docs"]
        logger.info("Beginning processing of #{model_name}, #{records.length} items found")

        records.each do |record|
          obj_id = record['id']
          next if @completed_ids.include?(obj_id)
          start_time = Time.now
          # Refresh cache
          usage_class.new(obj_id).to_flot
          total_time += Time.now - start_time

          progress_tracker.add_entry(obj_id)
          cnt += 1
          average_time = total_time / cnt
          logger.info("Progress: #{cnt} of #{total_entries}, average #{average_time}s per record") if cnt % REPORT_EVERY_N == 0
        end

        break if cnt >= total_entries
      end
      
    end

    def logger
      @logger ||= begin
        log_path = File.join(Rails.configuration.log_directory, 'stats_cache_output.log')
        Logger.new(log_path, progname: "stats cache")
      end
    end

    def progress_tracker
      @progress_tracker ||= begin
        tracker_path = File.join(Rails.configuration.log_directory, 'stats_cache_progress.log')
        Migrate::Services::ProgressTracker.new(tracker_path)
      end
    end
  end
end
