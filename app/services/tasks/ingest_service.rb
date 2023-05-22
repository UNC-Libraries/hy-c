# frozen_string_literal: true
module Tasks
  require 'tasks/migrate/services/progress_tracker'
  class IngestService
    attr_reader :temp, :admin_set, :depositor, :package_dir

    def initialize(config, status_service)
      logger.info("Beginning #{ingest_source} ingest")

      @config = config
      # Create temp directory for unzipped contents
      @temp = @config['unzip_dir']
      FileUtils.mkdir_p @temp unless File.exist?(@temp)

      @status_service = status_service

      # Should deposit works into an admin set
      admin_set_title = @config['admin_set']
      @admin_set = ::AdminSet.where(title: admin_set_title)&.first
      raise(ActiveRecord::RecordNotFound, "Could not find AdminSet with title #{admin_set_title}") unless @admin_set.present?

      @depositor = User.find_by(uid: @config['depositor_onyen'])
      raise(ActiveRecord::RecordNotFound, "Could not find User with onyen #{@config['depositor_onyen']}") unless @depositor.present?

      @package_dir = @config['package_dir']

      deposit_record
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
      @status_service.initialize_statuses(package_paths)

      package_paths.each.with_index(1) do |package_path, index|
        begin
          @status_service.status_in_progress(package_path)
          process_package(package_path, index)
          @status_service.status_complete(package_path)
        rescue => error
          stacktrace = "#{error.message}:\n#{error.backtrace.join('\n')}"
          logger.error("Failed to process package #{package_path}: #{stacktrace}")
          @status_service.status_failed(package_path, stacktrace)
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

    def ingest_progress_log
      @ingest_progress_log ||= begin
        log_path = File.join(Rails.configuration.log_directory, "#{ingest_source.downcase}_progress.log")
        Migrate::Services::ProgressTracker.new(log_path)
      end
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
