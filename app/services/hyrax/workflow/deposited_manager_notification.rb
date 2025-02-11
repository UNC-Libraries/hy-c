# frozen_string_literal: true
module Hyrax
  module Workflow
    # This notification service was created to allow some admin set managers to get notifications.
    # Using the default DepositedNotificaiton class for this would send deposit notifications
    # to all managers in all workflows instead of just in the manager-specific workflow.
    class DepositedManagerNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited_manager.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited_manager.message', title: title, link: (link_to work_id, document_path))
      end

      def print_instance_variables
        Rails.logger.info('Begin Print Variables')
        instance_variables.each_with_index do |var, index|
          Rails.logger.info("Variable #{index} : #{var} = #{instance_variable_get(var).inspect}")
        end
        Rails.logger.info('End Print Variables')
      end

      def users_to_notify
        # print_instance_variables
        # user_key = ActiveFedora::Base.find(work_id).depositor
        # Rails.logger.info("UTN User Key: #{user_key.inspect}")
        # res = ::User.find_by(uid: user_key)
        # Rails.logger.info("Users to notify result #{res}")


        all_recipients = @recipients['to']|| []  + @recipients['cc'] || []
        # emails = to_recipients.map(&:email)
        # emails <<  user.email
        # Rails.logger.info("UTNEmails #{emails}")
        super << all_recipients
      end

      # def users_to_notify
      #   print_instance_variables
      #   user_key = ActiveFedora::Base.find(work_id).depositor
      #   Rails.logger.info("UTN User Key: #{user_key.inspect}")
      #   res = ::User.find_by(uid: user_key)
      #   Rails.logger.info("Users to notify result #{res}")
      #   to_recipients = @recipients["to"]
      #   super << res
      # end

      # def users_to_notify
      #   user_key = ActiveFedora::Base.find(work_id).depositor
      #   Rails.logger.info("UTN User Key: #{user_key.inspect}")
      #   res = ::User.find_by(uid: user_key)
      #   Rails.logger.info("Users to notify result #{res}")
      #   not_res = nil
      #   super << not_res
      # end

      # def users_to_notify
      #   not_res = nil
      #   super << not_res
      # end
    end
  end
end
