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
                    JOIN permission_template_accesses pta ON pta.agent_id = r.name AND pta.agent_type = 'Group'
                    WHERE pta.permission_template_id = (
                        SELECT id FROM permission_templates WHERE source_id = '#{admin_set_id}'
                    )"
                    ).map { |row| row.symbolize_keys }


        Rails.logger.info("NOTIF 2 - QUERY INSPECT: #{users_and_roles.inspect}")

        Rails.logger.info("NOTIF 2 - QUERY RESULTS")
        users_and_roles.each do |query_result|
          puts "User ID: #{query_result[:user_id]}, Email: #{query_result[:email]}, Group: #{query_result[:group_name]}, Admin Set Role: #{query_result[:admin_set_role]}"
        end
        
        # Map [user_id, group_name, admin_set_role] -> [user_id, {role_name => count}]
        user_role_map = users_and_roles.each_with_object({}) do |query_result, h|
          user_id = query_result[:user_id].to_i
          h[user_id] ||= { 'view' => 0, 'manage' => 0 }
          h[user_id][query_result[:admin_set_role]] += 1

        end
        
      
        Rails.logger.info("NOTIF - USER ROLE MAP")
        # Also processing
        # Probable remove later
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
        only_viewers = user_role_map.select { |user_id, role_counts| role_counts['view'] > role_counts['manage'] }
        only_viewer_ids = only_viewers.keys.map(&:to_i)
      
        Rails.logger.info("NOTIF - EXCLUSIVELY VIEWERS")
        only_viewers.each do |k, v|
          Rails.logger.info "User: #{k}, Viewing: #{v['view']}, Managing: #{v['manage']}"
        end
        
        # Select recipients with a user id that is in the only_viewer_ids set
        Rails.logger.info("NOTIF - User IDs selected for notification: #{only_viewer_ids.inspect}")

        # Fetch users directly from the database
        res = User.where(id: only_viewer_ids)

        Rails.logger.info("NOTIF - QUERY INSPECTION - #{res.inspect}")

        Rails.logger.info("NOTIF - FINAL RECIPIENTS")
        res.each { |r| Rails.logger.info("User ID: #{r.id}, Email: #{r.email}") }
        res
      end
    end
  end
end
