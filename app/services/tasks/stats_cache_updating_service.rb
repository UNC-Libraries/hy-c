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
      @report_mutex = Mutex.new
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
      @obj_id_queue = ObjectIdQueue.new(model_name, @per_page)
      @obj_id_queue.enqueue_next_page # populate the first page of results
      logger.info("Beginning processing of #{model_name}, #{@obj_id_queue.total_entries} items found")
      total_time = 0
      cnt = 0
      batch_start_time = nil

      # Array of threads
      threads = []

      # Define the work to be done by each thread
      cache_update_proc = Proc.new do
        obj_id = @obj_id_queue.pop
        until obj_id.nil?
          # skip the object if its already been updated according to the progress tracker
          if @completed_ids.include?(obj_id)
            obj_id = @obj_id_queue.pop
            next
          end
          batch_start_time = Time.now if batch_start_time.nil?

          start_time = Time.now
          # Refresh cache
          update_individual_record(usage_class, obj_id)

          total_time += Time.now - start_time

          progress_tracker.add_entry(obj_id)

          @report_mutex.synchronize do
            cnt += 1
            logger.info("Progress: #{cnt} of #{@obj_id_queue.total_entries}. Average times per record: Individual #{total_time / cnt}s, total #{(Time.now - batch_start_time) /cnt}s") if cnt % REPORT_EVERY_N == 0
          end
          # Get next id
          obj_id = @obj_id_queue.pop
        end
      end

      # Start the threads
      @num_threads.times do
        threads << Thread.new(&cache_update_proc)
      end

      # Wait for all threads to finish
      threads.each(&:join)
    end

    def update_individual_record(usage_class, obj_id)
      error = nil
      3.times do |try_counter|
        begin
          usage_class.new(obj_id).to_flot
          return
        rescue OAuth2::Error => e
          # retrying
          error = e
        rescue Ldp::Gone => e
          logger.warn("Skipping #{obj_id}, it no longer exists")
          return
        end
      end
      logger.error("Failed to update record #{obj_id} due to OAuth failure after retries")
      logger.error [error.class.to_s, error.message, *error.backtrace].join($RS)
    end

    def logger
      @logger ||= begin
        log_path = File.join(Rails.configuration.log_directory, 'stats_cache_output.log')
        Logger.new(log_path, progname: 'stats cache')
      end
    end

    def progress_tracker
      @progress_tracker ||= begin
        tracker_path = File.join(Rails.configuration.log_directory, 'stats_cache_progress.log')
        Migrate::Services::ProgressTracker.new(tracker_path)
      end
    end

    class ObjectIdQueue < Queue
      attr_accessor :total_entries, :current_cnt

      def initialize(model_name, per_page)
        super()
        @mutex = Mutex.new
        @total_entries = nil
        @completed_obj_type = false
        @model_name = model_name
        @next_page_start = 0
        @per_page = per_page
      end

      def pop
        begin
          return super(true)
        rescue ThreadError => error
          # error raised if the queue was empty
        end

        @mutex.synchronize do
          enqueue_next_page
        end

        begin
          return super(true)
        rescue ThreadError => error
          # error raised if the queue was empty
        end
      end

      def enqueue_next_page
        resp = ActiveFedora::SolrService.get("has_model_ssim:#{@model_name}", rows: @per_page, start: @next_page_start)['response']
        # Record total entries when retrieving the first page of results
        @total_entries = resp['numFound'] if @total_entries.nil?

        # populate the queue with the next batch of ids
        resp['docs'].each do |record|
          self << record['id']
        end

        # Adjust index of the next page of results to retrieve
        @next_page_start += @per_page
      end
    end
  end
end
