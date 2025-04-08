# frozen_string_literal: true
module Tasks
  class PubmedIngestService
    include Tasks::IngestHelper
    def attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
      # Create a work object using the provided work_hash
      model_class = work_hash[:work_type].constantize
      work = model_class.find(work_hash[:work_id])
      depositor =  User.find_by(uid: depositor_onyen)
      file = attach_pdf_to_work(work, file_path, depositor, visibility)
      admin_set = ::AdminSet.where(id: work_hash[:admin_set_id]).first
      file.update(permissions_attributes: group_permissions(admin_set))
      file
    end
end
end
