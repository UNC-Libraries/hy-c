# frozen_string_literal: true
# [hyc-override] Overriding to allow updated content jobs to run immediately so file reference isn't lost
# https://github.com/samvera/hyrax/blob/v3.4.2/app/actors/hyrax/actors/base_actor.rb
Hyrax::Actors::BaseActor.class_eval do
  alias_method :original_create, :create
  def create(env)
    original_create(env) && apply_work_specific_permissions(env)
  end

  # @param [Hyrax::Actors::Environment] env
  # @return [Boolean] true if update was successful
  def update(env)
    apply_update_data_to_curation_concern(env)
    # [hyc-override] Log deleted people objects
    log_deleted_people_objects(env.attributes, env.curation_concern.id)
    apply_save_data_to_curation_concern(env)
    # [hyc-override] Apply work specific permissions
    apply_work_specific_permissions(env)
    next_actor.update(env) && save(env) && run_callbacks(:after_update_metadata, env)
  end

  private
  alias_method :original_save, :save
  def save(env, use_valkyrie: false)
    # [hyc-override] Save updated nested objects individually; they will not be updated with the rest of the attributes
    env.attributes.each do |k, _v|
      next unless (k.ends_with? '_attributes') && (!env.curation_concern.attributes[k.gsub('_attributes', '')].nil?)

      env.curation_concern.attributes[k.gsub('_attributes', '')].each do |person|
        person.persist!
      end
    end
    original_save(env, use_valkyrie: use_valkyrie)
  end

  # Cast any singular values from the form to multiple values for persistence
  # also remove any blank assertions
  # TODO this method could move to the work form.
  def clean_attributes(attributes)
    attributes[:license] = Array(attributes[:license]) if attributes.key? :license
    # [hyc-override] Overriding actor to cast rights statements as single valued
    # removed rights_statement-specific line of code so that it could be cast in `remove_blank_attributes!`
    # [hyc-override] remove index field if for some reason is added to permissions_attributes hashes
    unless attributes['permissions_attributes'].blank?
      permission_attrs = {}
      attributes['permissions_attributes'].each do |k, v|
        permission_attrs[k] = if !v['index'].blank?
                                v.except('index')
                              else
                                v
                              end
      end
      attributes['permissions_attributes'] = permission_attrs
    end
    remove_blank_attributes!(attributes).except('file_set')
  end

  def log_deleted_people_objects(attributes, work_id)
    attributes.each do |attr, set|
      if set.present? && attr.match(/_attributes/)
        set.each do |_k, v|
          if v['_destroy']
            File.open(ENV['DELETED_PEOPLE_FILE'], 'a+') do |file|
              file.puts work_id
            end
          end
        end
      end
    end
  end

  # [hyc-override] added this method to allow work-specific permissions to work
  def apply_work_specific_permissions(env)
    permissions_attributes = env.attributes['permissions_attributes']
    return true if permissions_attributes.blank?
    # File sets don't have admin sets. So updating them independently of their work should skip this update.
    # It doesn't seem possible for a FileSet to reach here, since they have their own actor that doesn't inherit from BaseActor?
    return true unless env.curation_concern.respond_to? :admin_set

    workflow = Sipity::Workflow.where(permission_template_id: env.curation_concern.admin_set.permission_template.id,
                                      active: true).first
    entity = Sipity::Entity.where(proxy_for_global_id: env.curation_concern.to_global_id.to_s).first_or_create!
    permissions_attributes.each do |_k, permission|
      # skip the pre-existing permissions since they have already been applied
      next unless permission['id'].blank?

      if permission['type'] == 'person'
        agent_type = 'User'
        agent_id = ::User.find_by(email: permission['name'])
      else
        agent_type = 'Hyrax::Group'
        agent_id = permission['name']
      end
      agents = [Sipity::Agent.where(proxy_for_id: agent_id, proxy_for_type: agent_type).first_or_create]

      roles = if permission['access'] == 'edit'
                'approving'
              else
                'viewing'
              end
      create_workflow_permissions(entity, agents, roles, workflow)
    end
  end

  # [hyc-override] added this method to allow work-specific permissions to work
  def create_workflow_permissions(entity, agents, roles, workflow)
    Hyrax::Workflow::PermissionGenerator.call(entity: entity,
                                              agents: agents,
                                              roles: roles,
                                              workflow: workflow)
  end
end
