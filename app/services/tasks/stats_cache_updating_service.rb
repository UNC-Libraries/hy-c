# frozen_string_literal: true
module Tasks
  require 'tasks/migrate/services/progress_tracker'

  class StatsCacheUpdatingService
    WORK_TYPES = ['Article', 'Artwork', 'DataSet', 'Dissertation', 'General', 'HonorsThesis', 'Journal', 'MastersPaper',
                'Multimed', 'ScholarlyWork']
    REPORT_EVERY_N = 10

    attr_accessor :per_page, :num_threads

    def initialize
      @completed_ids = progress_tracker.completed_set
      @per_page = 1000
      @obj_id_mutex = Mutex.new
      @num_threads = 6
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
      @total_entries = nil
      @current_cnt = 0
      @obj_id_queue = Queue.new
      @completed_obj_type = false
      @total_time = 0
      @model_name = model_name

      # Array of threads
      threads = []

      # Define the work to be done by each thread
      cache_update_proc = Proc.new do
        obj_id = next_obj_id
        until obj_id.nil?
          start_time = Time.now
          # Refresh cache
          usage_class.new(obj_id).to_flot
          @total_time += Time.now - start_time

          progress_tracker.add_entry(obj_id)

          # get next id
          obj_id = next_obj_id
        end
      end

      # Start the threads
      @num_threads.times do
        threads << Thread.new(&cache_update_proc)
      end

      # Wait for all threads to finish
      threads.each(&:join)
    end

    def next_obj_id
      @obj_id_mutex.synchronize do
        return nil if @completed_obj_type

        if @obj_id_queue.empty?
          resp = ActiveFedora::SolrService.get("has_model_ssim:#{@model_name}", :rows => @per_page, :start => @current_cnt)["response"]
          # Record total entries when retrieving the first page of results
          if @total_entries.nil?
            @total_entries = resp['numFound']
            logger.info("Beginning processing of #{@model_name}, #{@total_entries} items found")
          end
          
          records = resp["docs"]
          # No more items, mark as done to prevent other workers from searching for more ids
          if records.empty?
            @completed_obj_type = true
            return nil
          end
          # populate the queue with the next batch of ids
          records.each do |record|
            @obj_id_queue << record['id']
          end
        end

        @current_cnt += 1
        logger.info("Progress: #{@current_cnt} of #{@total_entries}, average #{@total_time / @current_cnt}s per record") if @current_cnt % REPORT_EVERY_N == 0
        @obj_id_queue.pop
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
