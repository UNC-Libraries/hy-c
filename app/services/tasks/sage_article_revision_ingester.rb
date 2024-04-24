# frozen_string_literal: true
module Tasks
  class SageArticleRevisionIngester < SageBaseArticleIngester
    attr_accessor :existing_id, :depositor

    def process_package
      existing_work = ActiveFedora::Base.find(@existing_id)
      file_sets = existing_work.file_sets
      @logger.error("Updating Article #{@existing_id} with DOI: #{@jats_ingest_work.identifier}")
      # Determine which parts of the work have been revised, which can be metadata and/or file
      changed = sections_changed
      if changed[:metadata]
        add_or_update_xml_file(existing_work, file_sets)
        update_work_metadata(existing_work)
      end
      if changed[:file]
        add_or_update_pdf_file(existing_work, file_sets)
      end
      existing_work.id
    end

    def update_work_metadata(existing_work)
      # Clear previous creators
      # Note: the old person objects are not deleted, only unlinked. creators_attributes _delete does not appear to delete the person objects
      existing_work.creators = []
      # update the metadata
      populate_article_metadata(existing_work)
      existing_work.save!
    end

    def add_or_update_xml_file(existing_work, file_sets)
      # upload new version of the metadata file
      metadata_fs = file_sets.detect { |fs| fs.label.end_with?('.xml') }
      if metadata_fs.nil?
        attach_xml_to_work(existing_work, @jats_ingest_work.xml_path, depositor)
        @status_service.status_in_progress(@package_name,
            error: StandardError.new("Package #{@package_name} is a revision but did not have an existing XML file. Adding new file."))
      else
        update_file_set(metadata_fs, @depositor, @jats_ingest_work.xml_path)
      end
    end

    def add_or_update_pdf_file(existing_work, file_sets)
      # upload new version of the file
      pdf_fs = file_sets.detect { |fs| fs.label.end_with?('.pdf') }
      pdf_path = pdf_file_path
      if pdf_fs.nil?
        attach_pdf_to_work(existing_work, pdf_path, depositor)
        @status_service.status_in_progress(@package_name,
            error: StandardError.new("Package #{@package_name} is a revision but did not have an existing PDF file. Adding new file."))
      else
        update_file_set(pdf_fs, @depositor, pdf_path)
      end
    end

    def sections_changed
      manifest_path = File.join(@unzipped_package_dir, 'manifest.xml')
      doc = Nokogiri::XML(File.read(manifest_path))
      files_changed = doc.xpath('/manifests/manifest[@status = "changed"]/@uri')
      {
        metadata: files_changed.any? { |uri| uri.value.end_with?('.xml') },
        file: files_changed.any? { |uri| uri.value.end_with?('.pdf') },
      }
    end

    def update_file_set(file_set, user, file_path)
      @logger.info("Updating file_set for #{file_path}")
      actor = Hyrax::Actors::FileSetActor.new(file_set, user)
      actor.update_content(File.open(file_path))
      # passing in an empty set of attributes so that this will update timestamps without changing other attributes
      actor.update_metadata({})
    end
  end
end
