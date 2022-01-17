class MigrationHelper
  def self.get_uuid_from_path(path)
    path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
  end

  def self.create_filepath_hash(filename, hash)
    File.open(filename) do |file|
      file.each do |line|
        value = line.strip
        key = get_uuid_from_path(value)
        hash[key] = value unless key.blank?
      end
    end
  end

  def self.get_collection_uuids(collection_ids_file)
    collection_uuids = Array.new
    File.open(collection_ids_file) do |file|
      file.each do |line|
        collection_uuids.append(get_uuid_from_path(line.strip)) if !line.blank? && !get_uuid_from_path(line.strip).blank?
      end
    end

    collection_uuids
  end

  def self.retry_operation(message = nil)
    begin
      retries ||= 0
      yield
    rescue Exception => e
      puts "[#{Time.now.to_s}] #{e}"
      puts e.backtrace.map { |x| x.match(/^\/net\/deploy\/ir\/test\/releases.*/) }.compact
      puts message unless message.nil?
      sleep(10)
      retry if (retries += 1) < 5
      # log full backtrace if not recovered
      puts e.backtrace
      # send abort message and backtrace to terminal
      raise("[#{Time.now}] could not recover; aborting migration\nbacktrace:\n#{e.backtrace}")
    end
  end

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
      unless resource.respond_to?(k.to_s + '=')
        # Log non-blank person data which is not saved
        puts "[#{Time.now.to_s}] #{identifier} missing: #{k}=>#{v}"
        metadata.delete(k.to_s.split('s_')[0] + '_display')
        metadata.delete(k)
      end
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

    puts "[#{Time.now.to_s}][#{identifier}] missing: #{missing}" unless missing.blank?

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
      permissions_array << { "type" => "group", "name" => manager_group.agent_id, "access" => "edit" }
    end
    viewer_groups.each do |viewer_group|
      permissions_array << { "type" => "group", "name" => viewer_group.agent_id, "access" => "read" }
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
