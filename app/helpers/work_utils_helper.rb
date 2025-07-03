# frozen_string_literal: true
module WorkUtilsHelper
  def self.fetch_work_data_by_alternate_identifier(identifier)
    query = "identifier_tesim:\"#{identifier}\" NOT has_model_ssim:(\"FileSet\")"
    work_data = ActiveFedora::SolrService.get(query, rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with alternate identifier: #{identifier}") if work_data.blank?
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, identifier)) if admin_set_data.blank?
    result = {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name,
      file_set_ids: work_data['file_set_ids_ssim']
    }
    result.compact.empty? ? nil : result
  end
  def self.fetch_work_data_by_fileset_id(fileset_id)
    # Retrieve the work related to the fileset
    work_data = ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with fileset id: #{fileset_id}") if work_data.blank?
    # Set the admin set to an empty hash if the solr query returns nil
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, fileset_id, :fileset)) if admin_set_data.blank?
    result = {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name,
      file_set_ids: work_data['file_set_ids_ssim']
    }
    result.compact.empty? ? nil : result
  end
  def self.fetch_work_data_by_id(work_id)
    work_data = ActiveFedora::SolrService.get("id:#{work_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with work id: #{work_id}") if work_data.blank?
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, work_id)) if admin_set_data.blank?
    result = {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name,
      file_set_ids: work_data['file_set_ids_ssim']
    }
    result.compact.empty? ? nil : result
  end

  def self.fetch_work_data_by_doi(doi)
    work_data = ActiveFedora::SolrService.get("doi_tesim:\"#{doi}\"", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with doi: #{doi}") if work_data.blank?
    admin_set_name = work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_name ? ActiveFedora::SolrService.get("title_tesim:#{admin_set_name} AND has_model_ssim:(\"AdminSet\")", { :rows => 1, 'df' => 'title_tesim'})['response']['docs'].first : {}
    Rails.logger.warn(self.generate_warning_message(admin_set_name, doi, :doi)) if admin_set_data.blank?
    result = {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_name: admin_set_name,
      file_set_ids: work_data['file_set_ids_ssim']
    }
    result.compact.empty? ? nil : result
  end

  def self.get_permissions_attributes(admin_set_id)
    # find admin set and manager groups for work
    manager_groups = Hyrax::PermissionTemplateAccess.joins(:permission_template)
                                                    .where(access: 'manage', agent_type: 'group')
                                                    .where(permission_templates: { source_id: admin_set_id })

    # find admin set and viewer groups for work
    viewer_groups = Hyrax::PermissionTemplateAccess.joins(:permission_template)
                                                   .where(access: 'view', agent_type: 'group')
                                                   .where(permission_templates: { source_id: admin_set_id })

    # update work permissions to give admin set managers edit access and viewer groups read access
    permissions_array = []
    manager_groups.each do |manager_group|
      permissions_array << { 'type' => 'group', 'name' => manager_group.agent_id, 'access' => 'edit' }
    end
    viewer_groups.each do |viewer_group|
      permissions_array << { 'type' => 'group', 'name' => viewer_group.agent_id, 'access' => 'read' }
    end

    permissions_array
  end


  private_class_method

  def self.generate_warning_message(admin_set_name, id, concern = :id)
    if admin_set_name.blank?
      logged_concern = 'id'
      case concern
      when :doi
        logged_concern = 'doi'
      when :fileset
        logged_concern = 'fileset id'
      end
      return "Could not find an admin set, the work with #{logged_concern}: #{id} has no admin set name."
    else
      return "No admin set found with title_tesim: #{admin_set_name}."
    end
  end

  def self.fetch_model_instance(work_type, work_id)
    raise ArgumentError, 'Both work_type and work_id are required' unless work_type.present? && work_id.present?

    work_type.constantize.find(work_id)
  rescue NameError, ActiveRecord::RecordNotFound => e
    Rails.logger.error("[WorkUtils] Failed to fetch model instance: #{e.message}")
    nil
  end

end
