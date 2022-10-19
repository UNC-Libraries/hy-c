# frozen_string_literal: true
# app/services/hyrax/workflow/notification_service.rb
# https://github.com/samvera/hyrax/blob/main/app/services/hyrax/workflow/notification_service.rb
Hyrax::Workflow::AbstractNotification.class_eval do
  # [hyc-override] Allow disabling of notifications via env
  alias_method :original_call, :call
  def call
    if ENV['ALLOW_NOTIFICATIONS']
      original_call
    else
      Rails.logger.info "\nNot sending messages\n"
    end
  end

  # [hyc-override] Override email text to use translation
  def message
    I18n.t('hyrax.notifications.workflow.review_advanced.message', title: title, work_id: work_id,
                                                                   document_path: document_path, user: user, comment: comment)
  end

  # [hyc-override] Overriding document_path method to return full url instead of the relative path
  # Replacing "_path" with "_url"
  def document_path
    key = document.model_name.singular_route_key
    Rails.application.routes.url_helpers.send("#{key}_url", document.id)
  end
end
