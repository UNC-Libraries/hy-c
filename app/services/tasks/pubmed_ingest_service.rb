# frozen_string_literal: true
module Tasks
    class PubmedIngestService
    include Tasks::IngestHelper
    def attach_pubmed_pdf(work_hash, file_path, depositor_onyen, visibility)
        model_class = work_hash[:work_type].constantize
        work = model_class.find(work_hash[:work_id])
        depositor =  User.find_by(uid: depositor_onyen)
        pdf_file = attach_pdf_to_work(work, file_path, depositor, visibility)
        admin_set = ::AdminSet.where(id: work_hash[:admin_set_id]).first
        pdf_file.update(permissions_attributes: group_permissions(admin_set))
        pdf_file
    end
end
end