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

      @ingest_progress_log = Migrate::Services::ProgressTracker.new(@config['ingest_progress_log']) if @config['ingest_progress_log']
    end

    def logger
      @logger ||= begin
        log_path = File.join(Rails.configuration.log_directory, "#{ingest_source.downcase}_ingest.log")
        Logger.new(log_path, progname: "#{ingest_source} ingest")
      end
    end
  end
end
