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

    def create_new_record(work_hash, file_path, depositor_onyen, visibility)
      representative_id = work_hash[:pmcid] || work_hash[:pmid]
      request_url = "https://www.ncbi.nlm.nih.gov/pmc/oai/oai.cgi?verb=GetRecord&identifier=oai:pubmedcentral.nih.gov:#{representative_id}metadataPrefix=oai_dc"
      res = HTTParty.get(request_url)
      # WIP: Remove Later
      puts "#{request_url} #{res.code} #{res.message}"
      if res.code != 200
        Rails.logger.error("Failed to fetch metadata for #{representative_id}: #{res.code} - #{res.message}")
        return nil
      end
      article = Article.new
      article
    end

    def set_basic_attributes(work_hash, file_path, depositor_onyen, visibility)
      # Set the basic attributes for the work
      work = work_hash[:work_type].constantize.new(work_hash)
      work.depositor = depositor_onyen
      work.admin_set_id = work_hash[:admin_set_id]
      work.visibility = visibility
      work.save!
      attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
    end
end
end
