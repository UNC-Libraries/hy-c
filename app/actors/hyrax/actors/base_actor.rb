# [hyc-override] Overriding actor to cast rights statements as single valued
# [hyc-override] Overriding actor to add work-specific workflow permissions
module Hyrax
  module Actors
    ##
    # Defines the basic save/destroy and callback behavior, intended to run
    # near the bottom of the actor stack.
    #
    # @example Defining a base actor for a custom work type
    #   module Hyrax
    #     module Actors
    #       class MyWorkActor < Hyrax::Actors::BaseActor; end
    #     end
    #   end
    #
    # @see Hyrax::Actor::AbstractActor
    class BaseActor < AbstractActor
      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if create was successful
      def create(env)
        apply_creation_data_to_curation_concern(env)
        apply_save_data_to_curation_concern(env)
        save(env) && next_actor.create(env) && run_callbacks(:after_create_concern, env) && apply_work_specific_permissions(env)
      end

      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if update was successful
      def update(env)
        apply_update_data_to_curation_concern(env)
        log_deleted_people_objects(env.attributes, env.curation_concern.id)
        apply_save_data_to_curation_concern(env)
        apply_work_specific_permissions(env)
        next_actor.update(env) && save(env) && run_callbacks(:after_update_metadata, env)
      end

      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if destroy was successful
      def destroy(env)
        env.curation_concern.in_collection_ids.each do |id|
          destination_collection = ::Collection.find(id)
          destination_collection.members.delete(env.curation_concern)
          destination_collection.update_index
        end
        env.curation_concern.destroy
      end

      private

      def run_callbacks(hook, env)
        Hyrax.config.callback.run(hook, env.curation_concern, env.user)
        true
      end

      def apply_creation_data_to_curation_concern(env)
        apply_depositor_metadata(env)
        apply_deposit_date(env)
      end

      def apply_update_data_to_curation_concern(_env)
        true
      end

      def apply_depositor_metadata(env)
        env.curation_concern.depositor = env.user.user_key
      end

      def apply_deposit_date(env)
        env.curation_concern.date_uploaded = TimeService.time_in_utc
      end

      def save(env)
        # [hyc-override] Save updated nested objects individually; they will not be updated with the rest of the attributes
        env.attributes.each do |k, _v|
          next unless (k.ends_with? '_attributes') && (!env.curation_concern.attributes[k.gsub('_attributes', '')].nil?)

          env.curation_concern.attributes[k.gsub('_attributes', '')].each do |person|
            person.persist!
          end
        end
        env.curation_concern.save
      end

      def apply_save_data_to_curation_concern(env)
        env.curation_concern.attributes = clean_attributes(env.attributes)
        env.curation_concern.date_modified = TimeService.time_in_utc
      end

      # Cast any singular values from the form to multiple values for persistence
      # also remove any blank assertions
      # TODO this method could move to the work form.
      def clean_attributes(attributes)
        attributes[:license] = Array(attributes[:license]) if attributes.key? :license
        # [hyc-override] Overriding actor to cast rights statements as single valued
        # removed rights_statement-specific line of code so that it could be cast in `remove_blank_attributes!`
        # [hyc-override] remove index field if for some reason is added to permissions_attributes hashes
        if !attributes['permissions_attributes'].blank?
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
        remove_blank_attributes!(attributes)
      end

      # If any attributes are blank remove them
      # e.g.:
      #   self.attributes = { 'title' => ['first', 'second', ''] }
      #   remove_blank_attributes!
      #   self.attributes
      # => { 'title' => ['first', 'second'] }
      def remove_blank_attributes!(attributes)
        multivalued_form_attributes(attributes).each_with_object(attributes) do |(k, v), h|
          h[k] = v.instance_of?(Array) ? v.select(&:present?) : v
        end
      end

      # Return the hash of attributes that are multivalued and not uploaded files
      def multivalued_form_attributes(attributes)
        attributes.select { |_, v| v.respond_to?(:select) && !v.respond_to?(:read) }
      end

      def log_deleted_people_objects(attributes, work_id)
        attributes.each do |attr, set|
          if attr.match(/_attributes/)
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
        return true unless env.curation_concern.respond_to? :admin_set

        workflow = Sipity::Workflow.where(permission_template_id: env.curation_concern.admin_set.permission_template.id,
                                          active: true).first
        entity = Sipity::Entity.where(proxy_for_global_id: env.curation_concern.to_global_id.to_s).first_or_create!
        permissions_attributes.each do |_k, permission|
          # skip the pre-existing permissions since they have already been applied
          next if !permission['id'].blank?

          if permission['type'] == 'person'
            agent_type = 'User'
            agent_id = ::User.find_by(uid: permission['name'])
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
  end
end
