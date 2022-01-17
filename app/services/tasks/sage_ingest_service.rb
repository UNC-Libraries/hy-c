module Tasks
  require 'tasks/migrate/services/progress_tracker'
  class SageIngestService
    attr_reader :package_dir, :ingest_progress_log, :admin_set, :depositor

    def initialize(args)
      config = YAML.load_file(args[:configuration_file])

      @admin_set = ::AdminSet.where(title: config['admin_set'])&.first
      raise(ActiveRecord::RecordNotFound, "Could not find AdminSet with title #{config['admin_set']}") unless @admin_set.present?

      @depositor = User.find_by(uid: config['depositor_onyen'])
      raise(ActiveRecord::RecordNotFound, "Could not find User with onyen #{config['depositor_onyen']}") unless @depositor.present?

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

          pdf_file_name = file_names.find { |name| name.match(/^(\S*).pdf/) }
          xml_file_name = file_names.find { |name| name.match(/^(\S*).xml/) }

          # parse xml
          ingest_work = JatsIngestWork.new(xml_path: File.join(dir, xml_file_name))
          # Create Article with metadata and save
          art_with_meta = article_with_metadata(ingest_work)
          # Add PDF file to Article (including FileSets)
          _art_with_fs = attach_file_set_to_work(work: art_with_meta, dir: dir, pdf_file_name: pdf_file_name, user: @depositor)
          # save object
          # set off background jobs for object?
          mark_done(orig_file_name) if package_ingest_complete?(dir, file_names)
        end
      end
    end

    def article_with_metadata(ingest_work)
      art = Article.new
      art.admin_set = @admin_set
      # required fields
      art.title = ingest_work.title
      art.creators_attributes = ingest_work.creators
      art.abstract = ingest_work.abstract
      art.date_issued = ingest_work.date_of_publication
      # additional fields
      art.copyright_date = ingest_work.copyright_date
      art.dcmi_type = ['http://purl.org/dc/dcmitype/Text']
      art.funder = ingest_work.funder
      art.identifier = ingest_work.identifier
      art.issn = ingest_work.issn
      art.journal_issue = ingest_work.journal_issue
      art.journal_title = ingest_work.journal_title
      art.journal_volume = ingest_work.journal_volume
      art.keyword = ingest_work.keyword
      art.license = ingest_work.license
      art.license_label = ingest_work.license_label
      art.page_end = ingest_work.page_end
      art.page_start = ingest_work.page_start
      art.publisher = ingest_work.publisher
      art.resource_type = ['Article']
      art.rights_holder = ingest_work.rights_holder
      art.rights_statement = 'http://rightsstatements.org/vocab/InC/1.0/'
      art.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      # fields not normally edited via UI
      art.date_uploaded = DateTime.current
      art.date_modified = DateTime.current

      art.save!
      # return the Article object
      art
    end

    def attach_file_set_to_work(work:, dir:, pdf_file_name:, user:)
      pdf = File.open(File.join(dir, pdf_file_name))
      fs = FileSet.create
      actor = Hyrax::Actors::FileSetActor.new(fs, user)
      actor.attach_to_work(work)
      pdf.close
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
