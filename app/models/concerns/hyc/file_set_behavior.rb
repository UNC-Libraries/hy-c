# frozen_string_literal: true
module Hyc
  module FileSetBehavior
    extend ActiveSupport::Concern
    include Hyrax::FileSetBehavior

    included do
      before_destroy :deregister_longleaf
    end

    def deregister_longleaf
      checksum = original_file.checksum.value
      Rails.logger.info("Calling deregistration from longleaf after delete of #{original_file} #{checksum}")
      DeregisterLongleafJob.perform_later(checksum)
    end

    def destroy
      Rails.logger.info("Overriding destroy for FileSet ID: #{id}")
      parent_work_id = member_of_work_ids.first
      Rails.logger.info("Cached Parent Work ID in destroy: #{parent_work_id}")
      update_parent_thumbnail_path(parent_work_id)
      super
    end

    # def cache_parent_work
    #   @cached_parent_work_id = member_of_work_ids.first
    #   Rails.logger.info("Cached Parent Work ID: #{@cached_parent_work_id}")
    # end
    
  #   def update_parent_thumbnail_path(parent_work_id)
  #     Rails.logger.info("update_parent_thumbnail_path called")
  #     # parent_work_2 = ActiveFedora::SolrService.get("id:#{parent_work_id}", rows: 1)['response']['docs'].first || {}
  #     # Rails.logger.info("parent_work_2: #{parent_work_2.inspect}")
  #     parent_work = ActiveFedora::Base.find(parent_work_id) rescue nil
  #     if parent_work.present?
  #       primary_file_set = parent_work.file_sets.first
  #       Rails.logger.info("Primary file set: #{primary_file_set.inspect}")
  #       # Rails.logger.info("Updating parent work: #{parent_work['id']}")
  #       Rails.logger.info("Inspect parent work: #{parent_work.inspect}")
  #       primary_file_set = ActiveFedora::SolrService.get("id:#{primary_file_set.id}", rows: 1)['response']['docs'].first || {}
  #       # new_thumbnail_path = parent_work.file_sets.first&.thumbnail_path
  #       # Rails.logger.info("New thumbnail path: #{new_thumbnail_path}")
  #       if primary_file_set.present?
  #         new_thumbnail_path = primary_file_set['thumbnail_path_ss']
  #         parent_work.update!(thumbnail_path: new_thumbnail_path)
  #         Rails.logger.info("Updated parent work thumbnail path")
  #       else
  #         Rails.logger.warn("Primary file set is nil or cannot be found")
  #       end
  #     else
  #       Rails.logger.warn("Parent work is nil or cannot be found")
  #     end
  #   end    
  # end

  def update_parent_thumbnail_path(parent_work_id)
    Rails.logger.info("update_parent_thumbnail_path called with parent_work_id: #{parent_work_id}")
  
    # Retrieve the parent work from Solr
    parent_work_solr_doc = ActiveFedora::SolrService.get("id:#{parent_work_id}", rows: 1)['response']['docs'].first
    # parent_work_solr_doc_2 = ActiveFedora::SolrService.get("id:#{parent_work_id}", rows: 1)['response']['docs'].first || {}
  
    if parent_work_solr_doc.present?
      Rails.logger.info("Inspect parent work Solr doc: #{parent_work_solr_doc.inspect}")
  
      # Retrieve the file set IDs from the parent work's Solr doc
      file_set_ids = parent_work_solr_doc['file_set_ids_ssim'] || []

      # if file_set_ids.length == 1
      #   Rails.logger.warn("Updating parent work thumbnail to default since the only file set is being deleted")
      #   return
      # end

      second_file_set_id = file_set_ids.second
      # if second_file_set_id.nil?
      #   Rails.logger.warn("Second file set ID not found; cannot update thumbnail")
      #   return
      # end

      primary_file_set_solr_doc = ActiveFedora::SolrService.get("id:#{second_file_set_id}", rows: 1)['response']['docs'].first if file_set_ids.any?
  
      if primary_file_set_solr_doc.present?
        # Extract the thumbnail path from the primary file set's Solr doc
        new_thumbnail_path = primary_file_set_solr_doc['thumbnail_path_ss']
  
        if new_thumbnail_path.present?
          # Update the parent work's thumbnail path in Solr
          # parent_work_solr_doc['thumbnail_path_ss'] = new_thumbnail_path
          # ActiveFedora::SolrService.delete(parent_work_id)
          # ActiveFedora::SolrService.add(parent_work_solr_doc)
          # ActiveFedora::SolrService.commit
          parent_work_solr_doc['thumbnail_path_ss'] = new_thumbnail_path
          parent_work_solr_doc['_version_'] = parent_work_solr_doc['_version_'] # Use the version for concurrency control
  
          ActiveFedora::SolrService.add(parent_work_solr_doc, params: { overwrite: true })
          ActiveFedora::SolrService.commit
          Rails.logger.info("Updated parent work thumbnail path to: #{new_thumbnail_path}")
        else
          Rails.logger.warn("Primary file set does not have a thumbnail path")
        end
      else
        Rails.logger.warn("Primary file set Solr document not found")
      end
    else
      Rails.logger.warn("Parent work Solr document not found")
    end
  end  
end
end
