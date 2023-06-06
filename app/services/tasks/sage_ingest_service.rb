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
      # Check for existing works based on the publisher DOI
      doi = ingest_work.identifier.first
      existing_id = existing_work_id(doi)

      package_ingester = construct_ingester(ingest_work, unzipped_package_dir, existing_id)
      work_id = package_ingester.process_package
      mark_done(orig_file_name(package_path), unzipped_package_dir, file_names)
      work_id
    end

    def construct_ingester(jats_ingest_work, unzipped_package_dir, existing_id)
      ingester = nil
      package_name = File.basename(unzipped_package_dir) + '.zip'
      doi = jats_ingest_work.identifier.first
      if existing_id.present?
        if SageIngestService.is_revision?(package_name)
          ingester = Tasks::SageArticleRevisionIngester.new
          ingester.existing_id = existing_id
        else
          raise "Work #{existing_id} already exists with DOI #{doi}, skipping package #{package_name}" if existing_id.present?
        end
      else
        if SageIngestService.is_revision?(package_name)
          # For a revision file with no existing work to update, continue with ingest but warn the user
          @status_service.status_in_progress(package_name,
                error: StandardError.new("Package #{package_name} indicates that it is a revision, but no existing work with DOI #{doi} was found. Creating a new work instead."))
        end
        ingester = Tasks::SageNewArticleIngester.new
        ingester.admin_set = @admin_set
      end
      ingester.package_file_names = Dir.entries(unzipped_package_dir)
      ingester.package_name = package_name
      ingester.jats_ingest_work = jats_ingest_work
      ingester.depositor = @depositor
      ingester.unzipped_package_dir = unzipped_package_dir
      ingester.status_service = @status_service
      ingester.logger = logger
      ingester.deposit_record = deposit_record
      ingester
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

    def metadata_file_path(file_names:, dir:)
      jats_xml_name = jats_xml_file_name(file_names: file_names)

      File.join(dir, jats_xml_name)
    end

    def jats_xml_file_name(file_names:)
      file_names -= ['manifest.xml']
      file_names.detect { |name| name.match(/^(\S*).xml/) }
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
