# frozen_string_literal: true
# Service used for storing information about the status of packages being submitted for ingest
module Tasks
  class IngestStatusService
    attr_reader :statuses

    # Note, if the json file specified in status_path does not already exist,
    # it will get created when any statuses are changed.
    def initialize(status_path)
      @status_path = status_path
      @statuses = Hash.new { |hash, key| hash[key] = {} }
    end

    # Initialize the status mapping to set all packages to pending
    def initialize_statuses(package_paths)
      package_paths.each do |package_path|
        set_status(package_path, 'Pending', persist: false)
      end
      persist_statuses
    end

    def status_complete(package_path)
      set_status(package_path, 'Complete')
    end

    def status_in_progress(package_path)
      set_status(package_path, 'In Progress')
    end

    def status_failed(package_path, error)
      set_status(package_path, 'Failed', error: error)
    end

    # Update the status of a package in the status mapping
    def set_status(package_path, new_status, error: nil, persist: true)
      filename = File.basename(package_path)
      @statuses[filename]['status'] = new_status
      @statuses[filename]['status_timestamp'] = Time.now.to_s
      if error.nil?
        @statuses[filename]['error'] = nil
      else
        @statuses[filename]['error'] = { 'message' => error.message, 'trace' => error.backtrace }
      end
      persist_statuses if persist
    end

    # Write the current status mapping out to disk
    def persist_statuses
      File.write(@status_path, @statuses.to_json)
    end

    # Loads statuses from persisted version on disk, and returns the statuses
    def load_statuses
      return unless File.exist?(@status_path)

      File.open(@status_path, 'r') do |file|
        @statuses = JSON.parse(file.read)
      end
    end

    def self.status_service_for_source(source)
      IngestStatusService.new(File.join(ENV['TEMP_STORAGE'], "#{source}_deposit_status.json"))
    end
  end
end
