# frozen_string_literal: true
module Tasks
  require 'tasks/migrate/services/progress_tracker'
  class IngestService
    attr_reader :temp, :admin_set, :depositor, :package_dir, :ingest_progress_log

    def initialize(config)
      logger.info("Beginning #{ingest_source} ingest")

      @config = config
      # Create temp directory for unzipped contents
      @temp = @config['unzip_dir']
      FileUtils.mkdir_p @temp unless File.exist?(@temp)

      # path to store outcome of attempts to ingest each package
      @outcome_path = @config['outcome_path']

      # Should deposit works into an admin set
      admin_set_title = @config['admin_set']
      @admin_set = ::AdminSet.where(title: admin_set_title)&.first
      raise(ActiveRecord::RecordNotFound, "Could not find AdminSet with title #{admin_set_title}") unless @admin_set.present?

      @depositor = User.find_by(uid: @config['depositor_onyen'])
      raise(ActiveRecord::RecordNotFound, "Could not find User with onyen #{@config['depositor_onyen']}") unless @depositor.present?

      @package_dir = @config['package_dir']

      deposit_record
      @ingest_progress_log = Migrate::Services::ProgressTracker.new(@config['ingest_progress_log']) if @config['ingest_progress_log']
    end

    def deposit_record_hash
      @deposit_record_hash ||= { title: "#{ingest_source} Ingest #{Time.new.strftime('%F %T')}",
                                 deposit_method: "Hy-C #{BRANCH}, #{self.class}",
                                 deposit_package_type: deposit_package_type,
                                 deposit_package_subtype: deposit_package_subtype,
                                 deposited_by: @depositor.uid }
    end

    def deposit_record
      @deposit_record ||= begin
        record = DepositRecord.new(@deposit_record_hash)
        record[:manifest] = nil
        record[:premis] = nil
        record.save!

        record
      end
    end

    def orig_file_name(package_path)
      File.basename(package_path, '.zip')
    end

    def unzip_dir(package_path)
      fname = orig_file_name(package_path)
      dirname = "#{@temp}/#{fname}"
      FileUtils.mkdir_p(dirname) unless File.exist?(dirname)
      dirname
    end

    def process_all_packages
      logger.info("Beginning ingest of #{count} #{ingest_source} packages")
      initialize_statuses()

      package_paths.each.with_index(1) do |package_path, index|
        begin
          status_in_progress(package_path)
          process_package(package_path, index)
          status_complete(package_path)
        rescue => error
          stacktrace = "#{error.message}:\n#{error.backtrace.join('\n')}"
          logger.error("Failed to process package #{package_path}: #{stacktrace}")
          status_failed(package_path, stacktrace)
        end
      end
      logger.info("Completing ingest of #{ingest_source} packages.")
    end

    def package_paths
      # sort zip files for tests
      @package_paths ||= Dir.glob("#{@package_dir}/*.zip").sort
    end

    def count
      @count ||= package_paths.count
    end

    def logger
      @logger ||= begin
        log_path = File.join(Rails.configuration.log_directory, "#{ingest_source.downcase}_ingest.log")
        Logger.new(log_path, progname: "#{ingest_source} ingest")
      end
    end

    # Initialize the outcome mapping to set all packages to pending
    def initialize_statuses()
      package_paths.each do |package_path|
        set_outcome_status(package_path, 'Pending', persist: false)
      end
      persist_outcomes()
    end

    def status_complete(package_path)
      set_outcome_status(package_path, 'Complete')
    end

    def status_in_progress(package_path)
      set_outcome_status(package_path, 'In Progress')
    end

    def status_failed(package_path, error)
      set_outcome_status(package_path, 'Failed', error: error)
    end

    # Update the status of a package in the outcome mapping
    def set_outcome_status(package_path, new_status, error: nil, persist: true)
      filename = File.basename(package_path)
      outcomes[filename][:status] = new_status
      outcomes[filename][:status_timestamp] = Time.now.to_s
      outcomes[filename][:error] = error
      persist_outcomes() if persist
    end

    # Write the current outcome mapping out to disk
    def persist_outcomes()
      File.write(@outcome_path, outcomes.to_json)
    end

    def load_outcomes()
      return unless File.exist?(@outcome_path)

      File.open(@outcome_path, 'r') do |file|
        @outcomes = JSON.parse(file.read)
      end
    end

    def outcomes()
      @outcomes ||= Hash.new { |hash, key| hash[key] = {} }
    end

    def extract_files(package_path)
      dirname = unzip_dir(package_path)
      logger.info("Extracting files from #{package_path} to #{dirname}")
      extracted_files = Zip::File.open(package_path) do |zip_file|
        zip_file.each do |file|
          file_path = File.join(dirname, file.name)
          zip_file.extract(file, file_path) unless File.exist?(file_path)
        end
      end
      logger.error("Unexpected package contents - #{extracted_files.count} files extracted from #{package_path}") unless valid_extract?(extracted_files)
      extracted_files
    rescue Zip::Error => e
      logger.info("#{package_path}, zip file error: #{e.message}")
      false
    end
  end
end
