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

      # Modified version of the users_to_notify method to only notify users that are exclusively viewers, since managers are assigned all roles they would get viewer notifications as well.
      def users_to_notify
        # Fetch recipients, similar to the AbstractNotification implementation of this method
        all_recipients = recipients.fetch(:to, []) + recipients.fetch(:cc, [])
        # Filter duplicates of users that might have been included in different groups
        all_recipients = all_recipients.uniq
      
        Rails.logger.info("NOTIF - Printing Recipients")
        all_recipients.each_with_index do |r, i|
          Rails.logger.info("##{i} : #{r.inspect}")
        end
      
        admin_set_query = ActiveFedora::SolrService.get("id:#{@work_id}")['response']['docs']
        return if admin_set_query.empty?
        admin_set_name = admin_set_query.first['admin_set_tesim'].first

        admin_set_query = ActiveFedora::SolrService.get("title_tesim:#{admin_set_name}")['response']['docs']
        return if admin_set_query.empty?
        admin_set_id = admin_set_query.first['id']
        # WIP: Users and groups has to be changed to a query that fetches info related to users and groups in an admin set instead of a workflow
        Rails.logger.info("NOTIF 2 - Admin Set Name: #{admin_set_name}, Admin Set ID: #{admin_set_id}")

        users_and_roles = ActiveRecord::Base.connection.execute(
                      "SELECT u.id AS user_id, u.email, r.name AS group_name, pta.access AS admin_set_role
                      FROM users u
                      JOIN roles_users ru ON u.id = ru.user_id
                      JOIN roles r ON ru.role_id = r.id
                      JOIN permission_template_accesses pta ON pta.agent_id = r.name AND pta.agent_type = 'group'
                      WHERE pta.permission_template_id = (
                          SELECT id FROM permission_templates WHERE source_id = ?
                      )", [admin_set_id]
                    ).map { |row| row.symbolize_keys } 


        # Query for agents related to the current workflow that have been assigned the roles managing or viewing. Agents can be groups or users
        # Proxy for id is either the user id or name of a group
        # Proxy for type is either Group or User
        # users_and_group_info = Sipity::Entity.where(workflow_id: @entity.workflow_id)
        #                    .joins('INNER JOIN sipity_workflow_roles ON sipity_workflow_roles.workflow_id = sipity_entities.workflow_id')
        #                    .joins('INNER JOIN sipity_workflow_responsibilities ON sipity_workflow_responsibilities.workflow_role_id = sipity_workflow_roles.id')
        #                    .joins('INNER JOIN sipity_roles ON sipity_roles.id = sipity_workflow_roles.role_id')
        #                    .joins('INNER JOIN sipity_agents ON sipity_agents.id = sipity_workflow_responsibilities.agent_id')
        #                    .where(sipity_roles: { name: ['managing', 'viewing'] })
        #                    .select('sipity_agents.proxy_for_id, sipity_agents.proxy_for_type, sipity_roles.name AS role_name')
        
        # Rails.logger.info("NOTIF 1 - QUERY INSPECT: #{users_and_group_info.to_sql}")

        Rails.logger.info("NOTIF 2 - QUERY INSPECT: #{users_and_roles.inspect}")
      
        # Rails.logger.info("NOTIF 1 - QUERY RESULTS")
        # users_and_group_info.each do |query_result|
        #   Rails.logger.info "Proxy For ID: #{query_result.proxy_for_id}, Proxy Type: #{query_result.proxy_for_type}, Role Name: #{query_result.role_name}"
        # end

        Rails.logger.info("NOTIF 2 - QUERY RESULTS")
        users_and_roles.each do |query_result|
          puts "User ID: #{query_result[:user_id]}, Email: #{query_result[:email]}, Group: #{query_result[:group_name]}, Admin Set Role: #{query_result[:admin_set_role]}"
        end
        
        # Map [user_id, group_name, admin_set_role] -> [user_id, {role_name => count}]
        # user_role_map = users_and_group_info.each_with_object({}) do |query_result, h|
        #   if query_result.proxy_for_type == 'User'
        #     user_id = query_result.proxy_for_id.to_i
        #     h[user_id] ||= {'viewing' => 0, 'managing' => 0}
        #     h[user_id][query_result.role_name] += 1
        #   elsif query_result.proxy_for_type == 'Hyrax::Group'
        #     group_name = query_result.proxy_for_id
        #     # Retrieve user ids associated with a group
        #     user_ids = ActiveRecord::Base.connection.execute(
        #       "SELECT u.id FROM users u
        #        JOIN roles_users ru ON u.id = ru.user_id
        #        JOIN roles r ON ru.role_id = r.id
        #        WHERE r.name = '#{group_name}'"
        #     ).map { |row| row["id"].to_i }  # Convert results to integer IDs        

        #     Rails.logger.info("NOTIF - Group '#{group_name}' contains users: #{user_ids}")
        
        #     user_ids.each do |user_id|
        #       h[user_id] ||= {'viewing' => 0, 'managing' => 0}
        #       h[user_id][query_result.role_name] += 1
        #     end
        #   end
        # end

        user_role_map = users_and_roles.each_with_object({}) do |query_result, h|
          user_id = query_result[:user_id].to_i
          h[user_id] ||= { 'view' => 0, 'manage' => 0 }
          h[user_id][query_result[:admin_set_role]] += 1
          # if query_result.proxy_for_type == 'User'
          #   user_id = query_result.proxy_for_id.to_i
          #   h[user_id] ||= {'viewing' => 0, 'managing' => 0}
          #   h[user_id][query_result.role_name] += 1
          # elsif query_result.proxy_for_type == 'Hyrax::Group'
          #   group_name = query_result.proxy_for_id
          #   # Retrieve user ids associated with a group
          #   user_ids = ActiveRecord::Base.connection.execute(
          #     "SELECT u.id FROM users u
          #      JOIN roles_users ru ON u.id = ru.user_id
          #      JOIN roles r ON ru.role_id = r.id
          #      WHERE r.name = '#{group_name}'"
          #   ).map { |row| row["id"].to_i }  # Convert results to integer IDs        

          #   Rails.logger.info("NOTIF - Group '#{group_name}' contains users: #{user_ids}")
        
          #   user_ids.each do |user_id|
          #     h[user_id] ||= {'viewing' => 0, 'managing' => 0}
          #     h[user_id][query_result.role_name] += 1
          #   end
          # end
        end
        
      
        Rails.logger.info("NOTIF - USER ROLE MAP")
        # Also processing
        user_role_map.each do |id, count|
          # Manager addition v: 1, m: 1
          # Admin addition v: 1, m: 1
          # Viewer addition: v: 1

          # All roles applied v: 3, m: 2
          # Manager + Viewer roles applied - v: 2 m: 1
          # Manager only applied - v: 1 m: 1 

          # Condition v count > m count
          viewing_count = count['view']
          managing_count = count['manage']
          send_notification = viewing_count > managing_count
          
          # Rails.logger.info "User: #{k}, Roles: #{count.to_a}"
          Rails.logger.info "LOG VIEWING/MANAGING COUNT - User: #{id}, Viewing Count: #{viewing_count}, Managing Count: #{managing_count}, send_notification: #{send_notification}"
        end

      
        # Select users that have the viewing role applied to them more times than the managing role
        only_viewers = user_role_map.select do |user_id, role_counts|
          role_counts['view'] > role_counts['manage']
        end
        only_viewer_ids = only_viewers.keys.map(&:to_i)
      
        Rails.logger.info("NOTIF - EXCLUSIVELY VIEWERS")
        only_viewers.each do |k, v|
          Rails.logger.info "User: #{k}, Viewing: #{v['view']}, Managing: #{v['manage']}"
        end
        
        # Select recipients with a user id that is in the only_viewer_ids set
        res = all_recipients.select { |r| only_viewer_ids.include?(r.id) }
      
        Rails.logger.info("NOTIF - FINAL RECIPIENTS")
        res.each do |r|
          Rails.logger.info("User ID: #{r.id}, Email: #{r.email}")
        end
      
        res
      end
    end
  end
end
