# frozen_string_literal: true
module WorkUtilsHelper
  def self.fetch_work_data_by_alternate_identifier(identifier)
    work_data = ActiveFedora::SolrService.get("identifier_tesim:\"#{identifier}\"", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with alternate identifier: #{identifier}") if work_data.blank?
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, identifier, false)) if admin_set_data.blank?
    {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name
    }
  end
  def self.fetch_work_data_by_fileset_id(fileset_id)
    # Retrieve the work related to the fileset
    work_data = ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with fileset id: #{fileset_id}") if work_data.blank?
    # Set the admin set to an empty hash if the solr query returns nil
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, fileset_id, true)) if admin_set_data.blank?
    {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name
    }
  end

  def self.fetch_work_data_by_id(work_id)
    work_data = ActiveFedora::SolrService.get("id:#{work_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with work id: #{work_id}") if work_data.blank?
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, work_id, false)) if admin_set_data.blank?
    {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name
    }
  end

  private_class_method

  def self.generate_warning_message(admin_set_name, id, is_fileset_id)
    if admin_set_name.blank?
      return "Could not find an admin set, the work with #{is_fileset_id ? 'fileset id' : 'id'}: #{id} has no admin set name."
    else
      return "No admin set found with title_tesim: #{admin_set_name}."
    end
  end
end
