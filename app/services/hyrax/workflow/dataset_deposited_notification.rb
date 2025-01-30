# frozen_string_literal: true
module Hyrax
    module Workflow
      class DatasetDepositedNotification < AbstractNotification
        private
  
        def subject
            I18n.t('hyrax.notifications.workflow.dataset_deposited.subject')
        end
  
        def message
            I18n.t('hyrax.notifications.workflow.dataset_deposited.message', title: title, link: (link_to work_id, document_path))
        end
  
        def users_to_notify
          user_key = ActiveFedora::Base.find(work_id).depositor
          # Only returning the depositor, excluding the default users provided by parent class
          [::User.find_by(uid: user_key)]
        end
      end
    end
  end
  