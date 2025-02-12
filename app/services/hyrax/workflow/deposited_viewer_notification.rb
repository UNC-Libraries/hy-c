# frozen_string_literal: true
module Hyrax
  module Workflow
    # This notification service was created to allow some admin set managers to get notifications.
    # Using the default DepositedNotificaiton class for this would send deposit notifications
    # to all managers in all workflows instead of just in the manager-specific workflow.
    class DepositedViewerNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited_manager.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited_manager.message', title: title, link: (link_to work_id, document_path))
      end

      def print_instance_variables
        instance_variables.each do |var|
          Rails.logger.info("#{var}: #{instance_variable_get(var)}")
        end
      end

      def users_to_notify
        print_instance_variables
        # Find admin set using work id
        admin_set = ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs'].first || {}
      end
    end
  end
end
