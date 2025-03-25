# frozen_string_literal: true
module Tasks
    class PubmedIngestService
    include Tasks::IngestHelper
    def initialize
    end

    def attach_pubmed_pdf(work, file_path, depositor, visibility)
        attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: visibility)
    end
end