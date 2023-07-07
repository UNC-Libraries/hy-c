# frozen_string_literal: true
module Tasks
  require 'tasks/migrate/services/progress_tracker'

  class StatsCacheUpdatingService
    WORK_TYPES = ['Article', 'Artwork', 'DataSet', 'Dissertation', 'General', 'HonorsThesis', 'Journal', 'MastersPaper',
                'Multimed', 'ScholarlyWork']
    REPORT_EVERY_N = 10

    attr_accessor :per_page, :num_threads, :failure_delay

    def initialize
      @per_page = 1000
      @report_mutex = Mutex.new
      @fail_wait_mutex = Mutex.new
      @num_threads = 6
      @failure_delay = 60
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

    def completed_ids
      @completed_ids ||= progress_tracker.completed_set
    end

    def update_records(model_name, usage_class)
      @obj_id_queue = ObjectIdQueue.new(model_name, @per_page)
      @obj_id_queue.enqueue_next_page # populate the first page of results
      logger.info("Beginning processing of #{model_name}, #{@obj_id_queue.total_entries} items found")
      total_time = 0
      count = 0
      skipped_count = 0
      batch_start_time = nil

      # Array of threads
      threads = []

      # Define the work to be done by each thread
      cache_update_proc = Proc.new do
        batch_start_time = Time.now
        obj_id = @obj_id_queue.pop
        until obj_id.nil?
          # skip the object if its already been updated according to the progress tracker
          if completed_ids.include?(obj_id)
            obj_id = @obj_id_queue.pop
            skipped_count += 1
            next
          end

          await_failure_delay
          # Refresh cache
          start_time = Time.now
          completed = update_individual_record(usage_class, obj_id)
          total_time += Time.now - start_time

          progress_tracker.add_entry(obj_id) if completed
          # Synchronize for reporting so we don't skip over any numbers a miss a report
          @report_mutex.synchronize do
            count += 1
            if count % REPORT_EVERY_N == 0
              logger.info("Progress: #{count + skipped_count} of #{@obj_id_queue.total_entries}." \
                " Average times per record: Individual #{total_time / count}s," \
                " batch #{(Time.now - batch_start_time) / REPORT_EVERY_N}s")
              batch_start_time = Time.now
            end
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

    # Makes the current thread wait until a delay caused by a failed request to GA completes
    def await_failure_delay
      while @fail_wait_mutex.locked?
        sleep(1.second)
      end
    end

    def update_individual_record(usage_class, obj_id)
      error = nil
      num_tries = 3
      num_tries.times do |try_counter|
        begin
          usage_class.new(obj_id).to_flot
          return true
        rescue Ldp::Gone => e
          logger.warn("Skipping #{obj_id}, it no longer exists")
          return true
        rescue StandardError => e
          # retrying after a delay, unless we are out of retries
          logger.warn("Failed to update record #{obj_id}: #{e.message}")
          delay_after_error(e) if try_counter < (num_tries - 1)
          error = e
        end
      end
      logger.error("Failed to update record #{obj_id} after retries")
      logger.error [error.class.to_s, error.message, *error.backtrace].join($RS)
      false
    end

    def delay_after_error(e)
      end_time = Time.now + @failure_delay.second
      # Too many requests for the day, so delay until the next day
      if e.message.include?('exceeded the daily request limit')
        # Delay until the next midnight west coast time, either today or the next day depending on current time
        end_time = Time.parse('3am')
        end_time += 24.hours if Time.now >= end_time
      elsif e.message.include?('blocked from the reporting API for at least an hour')
        end_time = Time.now + 60.minutes
      end
      # Start a lock to prevent other update requests from starting until the delay has completed
      @fail_wait_mutex.lock
      # Delay until end time, unless that time has already passed while waiting for the lock
      sleep(end_time - Time.now) if Time.now < end_time
      @fail_wait_mutex.unlock
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
      attr_accessor :total_entries, :current_count

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
