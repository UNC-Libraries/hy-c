# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/models/proxy_deposit_request.rb
ProxyDepositRequest.class_eval do
  def send_request_transfer_message_as_part_of_create
    user_link = link_to(sending_user.name, Hyrax::Engine.routes.url_helpers.user_path(sending_user))
    transfer_link = link_to(I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_create.transfer_link_label'), Hyrax::Engine.routes.url_helpers.transfers_path)
    # [hyc-override] our message contains additional work_link variable
    work_link = link_to work.title.first, "#{ENV['HYRAX_HOST']}/concern/#{work.class.to_s.underscore}s/#{work.id}"
    message = I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_create.message', user_link: user_link,
                                                                                             transfer_link: transfer_link,
                                                                                             work_link: work_link)
    Hyrax::MessengerService.deliver(::User.batch_user, receiving_user, message,
                                    I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_create.subject'))
  end

  def send_request_transfer_message_as_part_of_update
    # [hyc-override] our message contains additional title and receiving_user variables.
    work_link = link_to work.title.first, "#{ENV['HYRAX_HOST']}/concern/#{work.class.to_s.underscore}s/#{work.id}"
    message = I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_update.message', status: status,
                                                                                             title: work_link,
                                                                                             receiving_user: receiving_user)
    if receiver_comment.present?
      message += ' ' + I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_update.comments',
                              receiver_comment: receiver_comment)
    end
    Hyrax::MessengerService.deliver(::User.batch_user, sending_user, message,
                                    I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_update.subject',
                                           status: status))
  end
end
