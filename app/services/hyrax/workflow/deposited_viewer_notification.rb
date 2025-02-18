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

        # Query for users within groups assigned to the admin set
        groups_and_roles_query = ActiveRecord::Base.connection.execute("SELECT u.id AS user_id, u.email, r.name AS group_name, pta.access AS admin_set_role
                    FROM users u
                    JOIN roles_users ru ON u.id = ru.user_id
                    JOIN roles r ON ru.role_id = r.id
                    JOIN permission_template_accesses pta ON pta.agent_id = r.name AND pta.agent_type = 'group'
                    WHERE pta.permission_template_id = (
                        SELECT id FROM permission_templates WHERE source_id = '#{admin_set_id}'
                    )")
        # Query for users assigned admin set permissions directly
        users_and_roles_query = ActiveRecord::Base.connection.execute("SELECT u.id, u.email, pta.access AS admin_set_role
                    FROM users u
                    JOIN permission_template_accesses pta ON u.uid = pta.agent_id
                    WHERE pta.permission_template_id = (
                        SELECT id FROM permission_templates WHERE source_id = '#{admin_set_id}'
                    )
                    AND pta.agent_type = 'user';"
        )
        groups_and_roles = groups_and_roles_query.map { |row| row.symbolize_keys }
        users_and_roles = users_and_roles_query.map { |row| row.symbolize_keys }

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

        # Select users that have the viewing role applied to them equal to or more times than the managing role
        only_viewers = user_role_map.select { |user_id, role_counts| role_counts['view'] >= role_counts['manage'] }
        only_viewer_ids = only_viewers.keys.map(&:to_i)
        # Fetch users directly from the database
        res = ::User.where(id: only_viewer_ids).to_a
        # Add carbon copy users
        res << recipients['cc']
      end
    end
  end
end
