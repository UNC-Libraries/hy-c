# frozen_string_literal: true
module Tasks
  class SageBaseArticleIngester
    attr_accessor :jats_ingest_work, :package_name, :package_file_names, :depositor, :unzipped_package_dir, :deposit_record
    attr_accessor :status_service, :logger

    def pdf_file_path()
      filename = @package_file_names.detect { |name| name.match(/^(\S*).pdf/) }
      File.join(@unzipped_package_dir, filename)
    end

    def populate_article_metadata(art)
      # required fields
      art.title = @jats_ingest_work.title
      art.creators_attributes = @jats_ingest_work.creators
      art.abstract = @jats_ingest_work.abstract
      art.date_issued = @jats_ingest_work.date_of_publication
      # additional fields
      art.copyright_date = @jats_ingest_work.copyright_date
      art.dcmi_type = ['http://purl.org/dc/dcmitype/Text']
      art.funder = @jats_ingest_work.funder
      art.identifier = @jats_ingest_work.identifier
      art.issn = @jats_ingest_work.issn
      art.journal_issue = @jats_ingest_work.journal_issue
      art.journal_title = @jats_ingest_work.journal_title
      art.journal_volume = @jats_ingest_work.journal_volume
      art.keyword = @jats_ingest_work.keyword
      art.license = @jats_ingest_work.license
      art.license_label = @jats_ingest_work.license_label
      art.page_end = @jats_ingest_work.page_end
      art.page_start = @jats_ingest_work.page_start
      art.publisher = @jats_ingest_work.publisher
      art.resource_type = ['Article']
      art.rights_holder = @jats_ingest_work.rights_holder
      art.rights_statement = 'http://rightsstatements.org/vocab/InC/1.0/'
      art.rights_statement_label = 'In Copyright'
      art.deposit_record = @deposit_record.id
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
      @logger.info("Attaching file_set for #{file_path} to DOI: #{work.identifier.first}")
      file_set = FileSet.create
      actor = Hyrax::Actors::FileSetActor.new(file_set, user)
      actor.create_metadata(file_set_params)
      file = File.open(file_path)
      actor.create_content(file)
      actor.attach_to_work(work, file_set_params)
      file.close

      file_set
    end
  end
end