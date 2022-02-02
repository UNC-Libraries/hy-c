module Tasks
  require 'tasks/migrate/services/progress_tracker'
  class IngestService
    attr_reader :temp, :admin_set, :depositor, :package_dir, :ingest_progress_log

    def initialize(args)
      logger.info("Beginning #{ingest_source} ingest")

      @config = YAML.load_file(args[:configuration_file])
      # Create temp directory for unzipped contents
      @temp = @config['unzip_dir']
      FileUtils.mkdir_p @temp unless File.exist?(@temp)

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
      @deposit_record_hash ||= { title: "#{ingest_source} Ingest #{Time.new.strftime('%B %d, %Y')}",
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

    def process_packages
      logger.info("Beginning ingest of #{count} #{ingest_source} packages")

      package_paths.each.with_index(1) do |package_path, index|
        process_package(package_path, index)
      end
      logger.info("Completing ingest of #{ingest_source} Sage packages.")
    end

    def process_package(package_path, index)
      logger.info("Begin processing #{package_path} (#{index} of #{count})")
      _unzipped_package_dir = unzip_dir(package_path)
      # extract the files
      _file_names = extract_files(package_path).keys
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
  end
end
