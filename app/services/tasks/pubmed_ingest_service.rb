# frozen_string_literal: true
module Tasks
    class PubmedIngestService
    include Tasks::IngestHelper
    def attach_pubmed_pdf(work_hash, file_path, visibility)
        puts "PubmedIngestService attach_pubmed_pdf with work_type: #{work_hash[:work_type]} and work_id: #{work_hash[:work_id]}"
        # WIP: A bit unsure if I'm using this properly
        model_class = work_hash[:work_type].constantize
        work = model_class.find(work_hash[:work_id])
        puts "Article inspect #{work.inspect}"
        # attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: visibility)
    end
end
end