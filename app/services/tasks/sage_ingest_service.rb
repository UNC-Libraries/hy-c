module Tasks
  require 'tasks/migrate/services/progress_tracker'
  class SageIngestService
    attr_reader :package_dir, :ingest_progress_log, :admin_set_id

    def initialize(args)
      config = YAML.load_file(args[:configuration_file])

      @admin_set_id = ::AdminSet.where(title: config['admin_set']).first.id

      @package_dir = config['package_dir']
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
          next unless file_names.count == 2

          _pdf_file_name = file_names.find { |name| name.match(/^(\S*).pdf/) }
          xml_file_name = file_names.find { |name| name.match(/^(\S*).xml/) }
          # parse xml
          ingest_work = JatsIngestWork.new(xml_path: File.join(dir, xml_file_name))
          _article = build_article(ingest_work)
          # create Article object with xml and pdf
          # save object
          # set off background jobs for object?
          mark_done(orig_file_name) if package_ingest_complete?(dir, file_names)
        end
      end
    end

    def build_article(ingest_work)
      art = Article.new
      # required fields
      art.title = ingest_work.title
      art.creators_attributes = ingest_work.creators
      art.abstract = ingest_work.abstract
      art.date_issued = ingest_work.date_of_publication
      # additional fields
      art.copyright_date = ingest_work.copyright_date
      art.dcmi_type = ingest_work.dcmi_type
      art.identifier = ingest_work.identifier
      art.issn = ingest_work.issn
      art.journal_title = ingest_work.journal_title
      art.license = ingest_work.license
      art.rights_statement = ingest_work.rights_statement # if we save the rights statement, do we get the label for free?
      # fields not normally edited via UI
      art.date_uploaded = DateTime.current
      art.date_modified = DateTime.current

      art.save!
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
        extracted_files = Zip::File.open(package_path) do |zip_file|
          zip_file.each do |file|
            file_path = File.join(temp_dir, file.name)
            zip_file.extract(file, file_path)
          end
        end
        unless extracted_files.count == 2
          Rails.logger.tagged('Sage ingest') { Rails.logger.error("Unexpected package contents - more than two files extracted from #{package_path}") }
        end
        extracted_files
      rescue Zip::DestinationFileExistsError => e
        Rails.logger.tagged('Sage ingest') { Rails.logger.info("#{package_path}, zip file error: #{e.message}") }
      end
    end
  end
end
