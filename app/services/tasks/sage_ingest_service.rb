module Tasks
  class SageIngestService
    attr_reader :package_dir, :unzip_dir

    def initialize(args)
      config = YAML.load_file(args[:configuration_file])

      @package_dir = config['package_dir']
      @unzip_dir = config['unzip_dir']
    end

    def process_packages
      sage_package_paths = Dir.glob("#{@package_dir}/*.zip").sort
      count = sage_package_paths.count
      Rails.logger.tagged('Sage ingest') { Rails.logger.info("Beginning ingest of #{count} Sage packages") }
      sage_package_paths.each.with_index(1) do |package_path, index|
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("Begin processing #{package_path} (#{index} of #{count})") }
        orig_file_name = File.basename(package_path, '.zip')
        unzipped_package_dir = File.join(@unzip_dir, orig_file_name)
        file_names = extract_files(package_path).keys
        unless file_names.count == 2
          Rails.logger.tagged('Sage ingest') { Rails.logger.error("Unexpected package contents - more than two files extracted from #{package_path}") }
          next
        end
        pdf_file_name = file_names.first
        xml_file_name = file_names.last
        # parse xml
        # create object with xml and pdf
        # save object
        mark_done(unzipped_package_dir, "pdf") if pdf_complete?(unzipped_package_dir, pdf_file_name)
        mark_done(unzipped_package_dir, "xml") if xml_complete?(unzipped_package_dir, xml_file_name)
      end
    end

    def mark_done(unzipped_package_dir, file_type)
      done_path = File.join(unzipped_package_dir, ".done.#{file_type}")
      if File.exist?(done_path)
        modification_time = File.mtime(done_path)
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("#{unzipped_package_dir} .done.#{file_type} already present. File last modified #{modification_time}.") }
      else
        FileUtils.touch(done_path)
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("Marked #{file_type} complete #{unzipped_package_dir}") }
      end
    end

    # TODO: Make more assertions about what a completed PDF ingest looks like and test here
    def pdf_complete?(path_to_directory, file_name)
      file_exists = File.exist?(File.join(path_to_directory, file_name))
      if file_exists
        true
      else
        Rails.logger.tagged('Sage ingest') { Rails.logger.error("PDF processing not complete: #{path_to_directory}") }
        false
      end
    end

    # TODO: Make more assertions about what a completed XML ingest looks like and test here
    def xml_complete?(path_to_directory, file_name)
      file_exists = File.exist?(File.join(path_to_directory, file_name))
      if file_exists
        true
      else
        Rails.logger.tagged('Sage ingest') { Rails.logger.error("XML processing not complete: #{path_to_directory}") }
        false
      end
    end

    def extract_files(package_path)
      orig_file_name = File.basename(package_path, '.zip')
      dir_name = File.join(@unzip_dir, orig_file_name)
      FileUtils.mkdir_p(dir_name)
      begin
        Zip::File.open(package_path) do |zip_file|
          zip_file.each do |file|
            file_path = File.join(dir_name, file.name)
            zip_file.extract(file, file_path)
          end
        end
      rescue Zip::DestinationFileExistsError => e
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("#{package_path}, zip file error: #{e.message}") }
      end
    end
  end
end
