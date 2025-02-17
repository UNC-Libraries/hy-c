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
        work_data = WorkUtilsHelper.fetch_work_data_by_id(@work_id)
        return if work_data[:admin_set_id].blank?
        admin_set_id = work_data[:admin_set_id]
        admin_set_name = work_data[:admin_set_name]
        # WIP: Users and groups has to be changed to a query that fetches info related to users and groups in an admin set instead of a workflow
        # Rails.logger.info("NOTIF 2 - Admin Set Name: #{admin_set_name}, Admin Set ID: #{admin_set_id}")

        groups_and_roles_query = ActiveRecord::Base.connection.execute("SELECT u.id AS user_id, u.email, r.name AS group_name, pta.access AS admin_set_role
                    FROM users u
                    JOIN roles_users ru ON u.id = ru.user_id
                    JOIN roles r ON ru.role_id = r.id
                    JOIN permission_template_accesses pta ON pta.agent_id = r.name AND pta.agent_type = 'group'
                    WHERE pta.permission_template_id = (
                        SELECT id FROM permission_templates WHERE source_id = '#{admin_set_id}'
                    )")

        users_and_roles_query = ActiveRecord::Base.connection.execute("SELECT u.id, u.email, pta.access AS admin_set_role
                    FROM users u
                    JOIN permission_template_accesses pta ON u.uid = pta.agent_id
                    WHERE pta.permission_template_id = (
                        SELECT id FROM permission_templates WHERE source_id = '#{admin_set_id}'
                    )
                    AND pta.agent_type = 'user';"
        )



        # Rails.logger.info('NOTIF 2 - QUERY INSPECT 1')
        # groups_and_roles_query.each do |query_result|
        #   Rails.logger.info("RESULT INSPECT #{query_result.inspect}")
        # end

        # users_and_roles_query.each do |query_result|
        #   Rails.logger.info("RESULT INSPECT #{query_result.inspect}")
        # end

        groups_and_roles = groups_and_roles_query.map { |row| row.symbolize_keys }
        users_and_roles = users_and_roles_query.map { |row| row.symbolize_keys }
        # Rails.logger.info("NOTIF 2 - QUERY INSPECT: #{groups_and_roles.inspect}")

        # Rails.logger.info('NOTIF 2 - GROUP QUERY RESULTS')
        # groups_and_roles.each do |query_result|
        #   puts "User ID: #{query_result[:user_id]}, Email: #{query_result[:email]}, Group: #{query_result[:group_name]}, Admin Set Role: #{query_result[:admin_set_role]}"
        # end

        # Rails.logger.info('NOTIF 2 - USER QUERY RESULTS')
        # users_and_roles.each do |query_result|
        #   puts "User ID: #{query_result[:id]}, Email: #{query_result[:email]}, Admin Set Role: #{query_result[:admin_set_role]}"
        # end

        # Map [user_id, group_name, admin_set_role] -> [user_id, {role_name => count}]
        user_role_map = groups_and_roles.each_with_object({}) do |query_result, h|
          user_id = query_result[:user_id].to_i
          h[user_id] ||= { 'view' => 0, 'manage' => 0 }
          h[user_id][query_result[:admin_set_role]] += 1
        end

        users_and_roles.each do |query_result|
          user_id = query_result[:id].to_i
          user_role_map[user_id] ||= { 'view' => 0, 'manage' => 0 }
          user_role_map[user_id][query_result[:admin_set_role]] += 1
        end


        # Rails.logger.info('NOTIF - USER ROLE MAP')
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

          # Rails.logger.info "User: #{id}, Roles: #{count.to_a}"
          # Rails.logger.info "LOG VIEWING/MANAGING COUNT - User: #{id}, Viewing Count: #{viewing_count}, Managing Count: #{managing_count}, send_notification: #{send_notification}"
        end


        # Select users that have the viewing role applied to them more times than the managing role
        only_viewers = user_role_map.select { |user_id, role_counts| role_counts['view'] >= role_counts['manage'] }
        only_viewer_ids = only_viewers.keys.map(&:to_i)

        # Rails.logger.info('NOTIF - EXCLUSIVELY VIEWERS')
        # only_viewers.each do |k, v|
        #   Rails.logger.info "User: #{k}, Viewing: #{v['view']}, Managing: #{v['manage']}"
        # end

        # Select recipients with a user id that is in the only_viewer_ids set
        # Rails.logger.info("NOTIF - User IDs selected for notification: #{only_viewer_ids.inspect}")

        # Fetch users directly from the database
        res = ::User.where(id: only_viewer_ids).to_a

        # Rails.logger.info("NOTIF - QUERY INSPECTION - #{res.inspect}")

        # Rails.logger.info('NOTIF - FINAL RECIPIENTS')
        # res.each { |r| Rails.logger.info("User ID: #{r.id}, Email: #{r.email}") }
        res
      end
    end
  end
end
