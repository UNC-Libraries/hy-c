# frozen_string_literal: true
module WorkUtilsHelper
  def self.fetch_work_data_by_fileset_id(fileset_id)
    work = ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found for fileset id: #{fileset_id}") if work.blank?
    # Fetch the admin set related to the work
    admin_set_name = work['admin_set_tesim']&.first
    # If the admin set name is not nil, fetch the admin set
    # Set the admin set to an empty hash if the solr query returns nil
    admin_set = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name}", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first || {} : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, fileset_id)) if admin_set.blank?

    {
      work_id: work['id'],
      work_type: work.dig('has_model_ssim', 0),
      title: work['title_tesim']&.first,
      admin_set_id: admin_set['id'],
      admin_set_name: admin_set_name
    }
  end

  private_class_method

  def self.generate_warning_message(admin_set_name, fileset_id)
    if admin_set_name.blank?
      return "Could not find an admin set, the work with fileset id: #{fileset_id} has no admin set name."
    else
      return "No admin set found with title_tesim: #{admin_set_name}."
    end
  end
end
