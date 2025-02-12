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
        Rails.logger.info('CUSTOM - Printing Instance Variables')
        instance_variables.each do |var|
          Rails.logger.info("#{var}: #{instance_variable_get(var)}")
        end
      end

      def users_to_notify
        print_instance_variables
        all_recipients = recipients.fetch(:to, []) + recipients.fetch(:cc, [])
        all_recipients.uniq
        Rails.logger.info('NOTIF - Printing Recipients')
        all_recipients.each_with_index do |r, i|
          Rails.logger.info("##{i} : #{r.inspect}")
        end
      end
    end
  end
end
