# frozen_string_literal: true
module Tasks
    class PubmedIngestService
    include Tasks::IngestHelper
    def attach_pubmed_pdf(work_id, file_path, visibility)
        puts "PubmedIngestService attach_pubmed_pdf"
        # WIP: A bit unsure if I'm using this properly
        model_class = model_name.constantize
        work = model_class.find(work_id)
        puts "Article inspect #{work.inspect}"
        # attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: visibility)
    end
end
end