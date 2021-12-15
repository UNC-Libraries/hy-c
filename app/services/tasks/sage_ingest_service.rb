module Tasks
  require 'tasks/migrate/services/progress_tracker'
  class SageIngestService
    attr_reader :package_dir, :unzip_dir, :ingest_progress_log

    def initialize(args)
      config = YAML.load_file(args[:configuration_file])

      @package_dir = config['package_dir']
      @unzip_dir = config['unzip_dir']
      @ingest_progress_log = Migrate::Services::ProgressTracker.new(config['ingest_progress_log'])
    end

    def process_packages
      sage_package_paths = Dir.glob("#{@package_dir}/*.zip").sort
      count = sage_package_paths.count
      Rails.logger.tagged('Sage ingest') { Rails.logger.info("Beginning ingest of #{count} Sage packages") }
      sage_package_paths.each.with_index(1) do |package_path, index|
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("Begin processing #{package_path} (#{index} of #{count})") }
        orig_file_name = File.basename(package_path, '.zip')
        Dir.mktmpdir do |dir|
          file_names = extract_files(package_path, dir).keys
          unless file_names.count == 2
            Rails.logger.tagged('Sage ingest') { Rails.logger.error("Unexpected package contents - more than two files extracted from #{package_path}") }
            next
          end
          _pdf_file_name = file_names.first
          _xml_file_name = file_names.last
          # parse xml
          # create object with xml and pdf
          # save object
          mark_done(orig_file_name) if package_ingest_complete?(dir, file_names)
        end
      end
    end

    def mark_done(orig_file_name)
      Rails.logger.tagged('Sage ingest') { Rails.logger.info("Marked package ingest complete #{orig_file_name}") }
      @ingest_progress_log.add_entry(orig_file_name)
    end

    # TODO: Make more assertions about what a completed ingest looks like and test here
    def package_ingest_complete?(dir, file_names)
      return true if File.exist?(File.join(dir, file_names.first)) && File.exist?(File.join(dir, file_names.last))
      Rails.logger.tagged('Sage ingest') { Rails.logger.error("Package ingest not complete for #{file_names.first} and #{file_names.last}") }
      false
    end

    def extract_files(package_path, temp_dir)
      begin
        Zip::File.open(package_path) do |zip_file|
          zip_file.each do |file|
            file_path = File.join(temp_dir, file.name)
            zip_file.extract(file, file_path)
          end
        end
      rescue Zip::DestinationFileExistsError => e
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("#{package_path}, zip file error: #{e.message}") }
      end
    end
  end
end
