module Tasks
  class SageIngestService < IngestService
    def ingest_source
      'Sage'
    end

    def deposit_record
      @deposit_record ||= begin
        record = DepositRecord.new(deposit_record_hash)
        record[:manifest] = nil
        record[:premis] = nil
        record.save!

        record
      end
    end

    def process_packages
      # Create DepositRecord
      deposit_record

      super

      package_paths.each.with_index(1) do |package_path, index|
        logger.info("Begin processing #{package_path} (#{index} of #{count})")
        orig_file_name = File.basename(package_path, '.zip')
        dirname = extracted_package_directory(package_path)

        file_names = extract_files(package_path).keys
        unless file_names.count.between?(2, 3)
          logger.info("Error extracting #{package_path}: skipping zip file")
          next
        end

        pdf_file_name = file_names.find { |name| name.match(/^(\S*).pdf/) }

        jats_xml_path = jats_xml_path(file_names: file_names, dir: dirname)

        # parse xml
        ingest_work = JatsIngestWork.new(xml_path: jats_xml_path)

        # Create Article with metadata and save
        art_with_meta = article_with_metadata(ingest_work)
        create_sipity_workflow(work: art_with_meta)
        # Add PDF file to Article (including FileSets)
        attach_file_set_to_work(work: art_with_meta, dir: dirname, file_name: pdf_file_name, user: @depositor, visibility: art_with_meta.visibility)
        # Add xml metadata file to Article
        attach_file_set_to_work(work: art_with_meta, dir: dirname, file_name: jats_xml_file_name(file_names: file_names), user: @depositor, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
        mark_done(orig_file_name) if package_ingest_complete?(dirname, file_names)
      end
      logger.info("Completing ingest of #{count} Sage packages.")
    end

    # URI representing the type of packaging used for the original deposit represented by this record, such as CDR METS or BagIt.
    def deposit_package_type
      'https://sagepub.com'
    end

    def deposit_package_subtype
      'https://jats.nlm.nih.gov/publishing/'
    end

    def create_sipity_workflow(work:)
      # Create sipity record
      join = Sipity::Workflow.joins(:permission_template)
      workflow = join.where(permission_templates: { source_id: work.admin_set_id }, active: true)
      raise(ActiveRecord::RecordNotFound, "Could not find Sipity::Workflow with permissions template with source id #{work.admin_set_id}") unless workflow.present?

      workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
      raise(ActiveRecord::RecordNotFound, "Could not find Sipity::WorkflowState with workflow_id: #{workflow.first.id} and name: 'deposited'") unless workflow_state.present?

      Sipity::Entity.create!(proxy_for_global_id: work.to_global_id.to_s,
                             workflow: workflow.first,
                             workflow_state: workflow_state.first)
    end

    def jats_xml_path(file_names:, dir:)
      jats_xml_name = jats_xml_file_name(file_names: file_names)

      File.join(dir, jats_xml_name)
    end

    def jats_xml_file_name(file_names:)
      file_names -= ['manifest.xml']
      file_names.find { |name| name.match(/^(\S*).xml/) }
    end

    def article_with_metadata(ingest_work)
      logger.info("Creating Article from DOI: #{ingest_work.identifier}")
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
      art.rights_statement_label = 'In Copyright'
      art.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      art.deposit_record = deposit_record.id
      # fields not normally edited via UI
      art.date_uploaded = DateTime.current
      art.date_modified = DateTime.current

      art.deposit_record = deposit_record.id

      art.save!
      # return the Article object
      art
    end

    def attach_file_set_to_work(work:, dir:, file_name:, user:, visibility:)
      file_set_params = { visibility: visibility }
      logger.info("Attaching file_set for #{file_name} to DOI: #{work.identifier.first}")
      file_set = FileSet.create
      actor = Hyrax::Actors::FileSetActor.new(file_set, user)
      actor.create_metadata(file_set_params)
      file = File.open(File.join(dir, file_name))
      actor.create_content(file)
      actor.attach_to_work(work, file_set_params)
      file.close

      file_set
    end

    def mark_done(orig_file_name)
      logger.info("Marked package ingest complete #{orig_file_name}")
      @ingest_progress_log.add_entry(orig_file_name)
    end

    # TODO: Make more assertions about what a completed ingest looks like and test here
    def package_ingest_complete?(dir, file_names)
      return true if File.exist?(File.join(dir, file_names.first)) && File.exist?(File.join(dir, file_names.last))

      logger.error("Package ingest not complete for #{file_names.first} and #{file_names.last}")
      false
    end

    def extracted_package_directory(package_path)
      fname = package_path.split('.zip')[0].split('/')[-1]
      dirname = "#{@temp}/#{fname}"
      FileUtils.mkdir_p(dirname) unless File.exist?(dirname)
      dirname
    end

    def extract_files(package_path)
      dirname = extracted_package_directory(package_path)
      logger.info("Extracting files from #{package_path} to #{dirname}")
      extracted_files = Zip::File.open(package_path) do |zip_file|
        zip_file.each do |file|
          file_path = File.join(dirname, file.name)
          zip_file.extract(file, file_path) unless File.exist?(file_path)
        end
      end
      logger.error("Unexpected package contents - #{extracted_files.count} files extracted from #{package_path}") unless extracted_files.count.between?(2, 3)
      extracted_files
    rescue Zip::DestinationFileExistsError => e
      logger.info("#{package_path}, zip file error: #{e.message}")
      false
    end
  end
end
