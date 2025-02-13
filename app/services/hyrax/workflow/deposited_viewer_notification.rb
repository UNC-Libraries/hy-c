# frozen_string_literal: true
module Hyrax
  module Workflow
    # This notification service was created to exclusively notify viewers in the viewer-specific workflow.
    # Using the DepositedManagerNotificaiton class for this would send deposit notifications to managers as well.
    class DepositedViewerNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited_manager.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited_manager.message', title: title, link: (link_to work_id, document_path))
      end

      # def users_to_notify
      #   all_recipients = recipients.fetch(:to, []) + recipients.fetch(:cc, [])
      #   all_recipients.uniq

      #   users_and_roles = Sipity::Entity.where(workflow_id: @entity.workflow_id)
      #               .joins('INNER JOIN sipity_workflow_roles ON sipity_workflow_roles.workflow_id = sipity_entities.workflow_id')
      #               .joins('INNER JOIN sipity_workflow_responsibilities ON sipity_workflow_responsibilities.workflow_role_id = sipity_workflow_roles.id')
      #               .joins('INNER JOIN sipity_roles ON sipity_roles.id = sipity_workflow_roles.role_id')
      #               .joins('INNER JOIN sipity_agents ON sipity_agents.id = sipity_workflow_responsibilities.agent_id')
      #               .where(sipity_roles: { name: ['managing', 'viewing'] })  # Filters results by role name
      #               .select('sipity_agents.proxy_for_id, sipity_roles.name AS role_name')

      #   user_role_map = users_and_roles.each_with_object({}) do |record, h|
      #     user_id = record.proxy_for_id.to_i
      #     h[user_id] ||= Set.new
      #     h[user_id] << record.role_name
      #   end

      #   only_viewers = user_role_map.select { |user_id, roles| roles.include?('viewing') }

      #   all_recipients.select { |r| r.id.in?(only_viewers.keys) }
      # end

      def users_to_notify
        all_recipients = recipients.fetch(:to, []) + recipients.fetch(:cc, [])
        all_recipients.uniq
      
        Rails.logger.info("NOTIF - Printing Recipients")
        all_recipients.each_with_index do |r, i|
          Rails.logger.info("##{i} : #{r.inspect}")
        end
      
        users_and_group_info = Sipity::Entity.where(workflow_id: @entity.workflow_id)
                           .joins('INNER JOIN sipity_workflow_roles ON sipity_workflow_roles.workflow_id = sipity_entities.workflow_id')
                           .joins('INNER JOIN sipity_workflow_responsibilities ON sipity_workflow_responsibilities.workflow_role_id = sipity_workflow_roles.id')
                           .joins('INNER JOIN sipity_roles ON sipity_roles.id = sipity_workflow_roles.role_id')
                           .joins('INNER JOIN sipity_agents ON sipity_agents.id = sipity_workflow_responsibilities.agent_id')
                           .where(sipity_roles: { name: ['managing', 'viewing'] })
                           .select('sipity_agents.proxy_for_id, sipity_agents.proxy_for_type, sipity_roles.name AS role_name')
      
        Rails.logger.info("NOTIF - QUERY INSPECT: #{users_and_group_info.to_sql}")
      
        Rails.logger.info("NOTIF - QUERY RESULTS")
        users_and_group_info.each do |record|
          Rails.logger.info "Proxy For ID: #{record.proxy_for_id}, Proxy Type: #{record.proxy_for_type}, Role Name: #{record.role_name}"
        end

        group_users = users_and_group_info.each_with_object([]) do |record, user_ids|
          if record.proxy_for_type == 'Hyrax::Group'
            user_ids.concat(User.joins(:roles).where(roles: { name: record.proxy_for_id }).pluck(:id))
          else
            user_ids << record.proxy_for_id.to_i
          end
      
        user_role_map = users_and_group_info.each_with_object({}) do |record, h|
          if record.proxy_for_type == 'User'
          # if record.proxy_for_type == 'User'
            user_id = record.proxy_for_id.to_i
            h[user_id] ||= Set.new
            h[user_id] << record.role_name
          elsif record.proxy_for_type == 'Hyrax::Group'
            # Group role inheritance
            group_name = record.proxy_for_id
            
            user_ids = ActiveRecord::Base.connection.execute(
              "SELECT u.id FROM users u
               JOIN roles_users ru ON u.id = ru.user_id
               JOIN roles r ON ru.role_id = r.id
               WHERE r.name = '#{group_name}'"
            ).map { |row| row["id"].to_i }  # Convert results to integer IDs        
        
            Rails.logger.info("NOTIF - Group '#{group_name}' contains users: #{user_ids}")
        
            user_ids.each do |user_id|
              h[user_id] ||= Set.new
              h[user_id] << record.role_name  # Inherit group's role
            end
          end
        end
      
        Rails.logger.info("NOTIF - USER ROLE MAP")
        user_role_map.each do |k, v|
          Rails.logger.info "User: #{k}, Roles: #{v.to_a}"
        end
      
        only_viewers = user_role_map.select { |user_id, roles| roles.include?('viewing') }
      
        Rails.logger.info("NOTIF - EXCLUSIVELY VIEWERS")
        only_viewers.each do |k, v|
          Rails.logger.info "User: #{k}, Roles: #{v.to_a}"
        end
      
        res = all_recipients.select { |r| only_viewers.keys.include?(r.id) }
      
        Rails.logger.info("NOTIF - FINAL RECIPIENTS")
        res.each do |r|
          Rails.logger.info("User ID: #{r.id}, Email: #{r.email}")
        end
      
        res
      end
    end
  end
end
