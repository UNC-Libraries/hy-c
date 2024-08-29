# frozen_string_literal: true
module WorkUtilsHelper
  def self.fetch_work_data_by_fileset_id(fileset_id)
    work = ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found for fileset id: #{fileset_id}") if work.blank?
    # Fetch the admin set related to the work
    admin_set_name = work['admin_set_tesim']&.first
    # If the admin set name is not nil, fetch the admin set
    # Set the admin set to an empty hash if the solr query returns nil
    admin_set = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name}", rows: 1)['response']['docs'].first || {} : {}
    Rails.logger.warn("No admin set found for fileset id: #{fileset_id}") if admin_set.blank?

    {
      work_id: work['id'] || 'Unknown',
      work_type: work.dig('has_model_ssim', 0) || 'Unknown',
      title: work['title_tesim']&.first || 'Unknown',
      admin_set_id: admin_set['id'] || 'Unknown',
      admin_set_name: admin_set_name || 'Unknown'
    }
  end
end
