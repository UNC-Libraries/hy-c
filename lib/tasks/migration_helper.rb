# frozen_string_literal: true
class MigrationHelper
  def self.check_enumeration(metadata, resource, identifier)
    # Singularize non-enumerable attributes and make sure enumerable attributes are arrays
    metadata.each do |k, v|
      metadata[k] = if resource.attributes.keys.member?(k.to_s) && !resource.attributes[k.to_s].respond_to?(:each) && metadata[k].respond_to?(:each)
                      v.first
                    elsif resource.attributes.keys.member?(k.to_s) && resource.attributes[k.to_s].respond_to?(:each) && !metadata[k].respond_to?(:each)
                      Array(v)
                    else
                      v
                    end
    end

    # Only keep attributes which apply to the given work type
    metadata.select { |k, _v| k.to_s.ends_with? '_attributes' }.each do |k, v|
      next if resource.respond_to?("#{k}=")

      # Log non-blank person data which is not saved
      puts "[#{Time.now}] #{identifier} missing: #{k}=>#{v}"
      metadata.delete("#{k.to_s.split('s_')[0]}_display")
      metadata.delete(k)
    end

    # Only keep attributes which apply to the given work type
    resource.attributes = metadata.reject { |k, _v| !resource.attributes.keys.member?(k.to_s) unless k.to_s.ends_with? '_attributes' }

    # Log other non-blank data which is not saved
    missing = metadata.except(*resource.attributes.keys, 'contained_files', 'cdr_model_type', 'visibility',
                              'creators_attributes', 'contributors_attributes', 'advisors_attributes',
                              'arrangers_attributes', 'composers_attributes', 'funders_attributes',
                              'project_directors_attributes', 'researchers_attributes', 'reviewers_attributes',
                              'translators_attributes', 'dc_title', 'premis_files', 'embargo_release_date',
                              'visibility_during_embargo', 'visibility_after_embargo', 'visibility',
                              'member_of_collections', 'based_near_attributes')

    puts "[#{Time.now}][#{identifier}] missing: #{missing}" unless missing.blank?

    resource
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

  # Use language code to get iso639-2 uri from service
  # TODO: Use multi-line version for conditional
  def self.get_language_uri(language_codes)
    Array.wrap(language_codes).map do |e|
      LanguagesService.label("http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}") ? "http://id.loc.gov/vocabulary/iso639-2/#{e.downcase}" : e
    end
  end
end
