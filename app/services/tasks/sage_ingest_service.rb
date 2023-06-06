# frozen_string_literal: true
module Tasks
  class SageIngestService < IngestService
    def ingest_source
      'Sage'
    end

    # URI representing the type of packaging used for the original deposit represented by this record, such as CDR METS or BagIt.
    def deposit_package_type
      'https://sagepub.com'
    end

    # Subclassification of the packaging type for this deposit, such as a METS profile.
    def deposit_package_subtype
      'https://jats.nlm.nih.gov/publishing/'
    end

    def self.is_revision?(filename)
      File.basename(filename).match?(/\.r[0-9]{4}-[0-9]{2}-[0-9]{2}/)
    end

    def process_package(package_path, _index)
      unzipped_package_dir = unzip_dir(package_path)

      file_names = extract_files(package_path).keys

      raise "Error extracting #{package_path}: skipping zip file" if unzipped_package_dir.blank?

      raise "Error extracting #{package_path}: skipping zip file" unless file_names.count.between?(2, 3)

      metadata_file_path = metadata_file_path(dir: unzipped_package_dir, file_names: file_names)

      # parse xml
      ingest_work = JatsIngestWork.new(xml_path: metadata_file_path)

      if SageIngestService.is_revision?(package_path)
        doi = ingest_work.identifier.first
        existing_id = existing_work_id(doi)
        # even if the file is marked as a revision, if there is no existing work then treat it as new
        if existing_id.present?
          process_revision(ingest_work, package_path, unzipped_package_dir, file_names, existing_id)
          mark_done(orig_file_name(package_path), unzipped_package_dir, file_names)
          return existing_id
        else
          @status_service.status_in_progress(package_path,
              error: StandardError.new("Package #{File.basename(package_path)} indicates that it is a revision, but no existing work with DOI #{doi} was found. Creating a new work instead."))
        end
      end

      new_id = process_new_work(ingest_work, unzipped_package_dir, file_names)
      mark_done(orig_file_name(package_path), unzipped_package_dir, file_names)
      new_id
    end

    def process_new_work(ingest_work, unzipped_package_dir, file_names)
      logger.error("Creating new Article with DOI: #{ingest_work.identifier}")
      # Create Article with metadata and save
      art_with_meta = article_with_metadata(ingest_work)
      create_sipity_workflow(work: art_with_meta)
      # Add PDF file to Article (including FileSets)
      pdf_path = pdf_file_path(file_names, unzipped_package_dir)

      attach_pdf_to_work(art_with_meta, pdf_path)
      # Add xml metadata file to Article
      attach_xml_to_work(art_with_meta, ingest_work.xml_path)
      art_with_meta.id
    end

    def process_revision(ingest_work, package_path, unzipped_package_dir, file_names, existing_id)
      existing_work = ActiveFedora::Base.find(existing_id)
      file_sets = existing_work.file_sets
      logger.error("Updating Article #{existing_id} with DOI: #{ingest_work.identifier}")
      # Determine which parts of the work have been revised, which can be metadata and/or file
      changed = sections_changed(unzipped_package_dir)
      if changed[:metadata]
        # upload new version of the metadata file
        metadata_fs = file_sets.detect { |fs| fs.label.end_with?('.xml') }
        if metadata_fs.nil?
          attach_xml_to_work(existing_work, ingest_work.xml_path)
          @status_service.status_in_progress(package_path,
              error: StandardError.new("Package #{File.basename(package_path)} is a revision but did not have an existing XML file. Adding new file."))
        else
          update_file_set(metadata_fs, @depositor, ingest_work.xml_path)
        end
        # Clear previous creators
        # Note: the old person objects are not deleted, only unlinked. creators_attributes _delete does not appear to delete the person objects
        existing_work.creators = []
        # update the metadata
        populate_article_metadata(ingest_work, existing_work)
        existing_work.save!
      end
      if changed[:file]
        # upload new version of the file
        pdf_fs = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
        pdf_path = pdf_file_path(file_names, unzipped_package_dir)
        if pdf_fs.nil?
          attach_pdf_to_work(existing_work, pdf_path)
          @status_service.status_in_progress(package_path,
              error: StandardError.new("Package #{File.basename(package_path)} is a revision but did not have an existing PDF file. Adding new file."))
        else
          update_file_set(pdf_fs, @depositor, pdf_path)
        end
      end
    end

    def sections_changed(unzipped_package_dir)
      manifest_path = File.join(unzipped_package_dir, 'manifest.xml')
      doc = Nokogiri::XML(File.read(manifest_path))
      files_changed = doc.xpath('/manifests/manifest[@status = "changed"]/@uri')
      {
        metadata: files_changed.any? { |uri| uri.value.end_with?('.xml') },
        file: files_changed.any? { |uri| uri.value.end_with?('.pdf') },
      }
    end

    def existing_work_id(vendor_doi)
      search_doi = vendor_doi.gsub(/.*doi.org/, '')
      resp = Hyrax::SolrService.get("identifier_tesim:\"#{search_doi}\"")
      doc = resp['response']['docs'].first
      if doc.blank?
        nil
      else
        doc['id']
      end
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

    def metadata_file_path(file_names:, dir:)
      jats_xml_name = jats_xml_file_name(file_names: file_names)

      File.join(dir, jats_xml_name)
    end

    def jats_xml_file_name(file_names:)
      file_names -= ['manifest.xml']
      file_names.detect { |name| name.match(/^(\S*).xml/) }
    end

    def pdf_file_path(file_names, dir)
      filename = file_names.detect { |name| name.match(/^(\S*).pdf/) }
      File.join(dir, filename)
    end

    def article_with_metadata(ingest_work)
      logger.info("Creating Article from DOI: #{ingest_work.identifier}")
      art = Article.new
      art.admin_set = @admin_set
      populate_article_metadata(ingest_work, art)
      art.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      art.save!
      # return the Article object
      art
    end

    def populate_article_metadata(ingest_work, art)
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
      art.deposit_record = deposit_record.id
      # fields not normally edited via UI
      art.date_uploaded = DateTime.current
      art.date_modified = DateTime.current
    end

    def attach_pdf_to_work(work, file_path)
      attach_file_set_to_work(work: work, file_path: file_path, user: @depositor, visibility: work.visibility)
    end

    def attach_xml_to_work(work, file_path)
      attach_file_set_to_work(work: work, file_path: file_path, user: @depositor, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    end

    def attach_file_set_to_work(work:, file_path:, user:, visibility:)
      file_set_params = { visibility: visibility }
      logger.info("Attaching file_set for #{file_path} to DOI: #{work.identifier.first}")
      file_set = FileSet.create
      actor = Hyrax::Actors::FileSetActor.new(file_set, user)
      actor.create_metadata(file_set_params)
      file = File.open(file_path)
      actor.create_content(file)
      actor.attach_to_work(work, file_set_params)
      file.close

      file_set
    end

    def update_file_set(file_set, user, file_path)
      logger.info("Updating file_set for #{file_path}")
      actor = Hyrax::Actors::FileSetActor.new(file_set, user)
      actor.update_content(File.open(file_path))
      actor.update_metadata({})
    end

    def mark_done(orig_file_name, unzipped_package_dir, file_names)
      return unless package_ingest_complete?(unzipped_package_dir, file_names)
      logger.info("Marked package ingest complete #{orig_file_name}")
      ingest_progress_log.add_entry(orig_file_name)
    end

    # TODO: Make more assertions about what a completed ingest looks like and test here
    def package_ingest_complete?(dir, file_names)
      return true if File.exist?(File.join(dir, file_names.first)) && File.exist?(File.join(dir, file_names.last))

      logger.error("Package ingest not complete for #{file_names.first} and #{file_names.last}")
      false
    end

    def valid_extract?(extracted_files)
      return true if extracted_files.count.between?(2, 3)

      false
    end
  end
end
