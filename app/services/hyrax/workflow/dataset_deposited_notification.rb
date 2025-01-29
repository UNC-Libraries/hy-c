# app/services/hyrax/workflow/dataset_deposited_notification.rb
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

        # WIP: Depositor + Super
        # Notify users when a dataset is deposited
          def users_to_notify
            # return [] unless dataset?

            user_key = ActiveFedora::Base.find(work_id).depositor
            super << ::User.find_by(uid: user_key)
          end

          def dataset?
            entity.resource_type&.include?(I18n.t('activefedora.models.data_set'))
          end
        end
    end
end
