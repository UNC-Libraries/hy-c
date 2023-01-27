# frozen_string_literal: true
# https://github.com/samvera/hyrax/tree/v2.9.6/app/models/file_download_stat.rb
ProxyDepositRequest.class_eval do
  def send_request_transfer_message_as_part_of_create
    user_link = link_to(sending_user.name, Hyrax::Engine.routes.url_helpers.user_path(sending_user))
    transfer_link = link_to(I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_create.transfer_link_label'), Hyrax::Engine.routes.url_helpers.transfers_path)
    work_link = link_to work.title.first, "#{ENV['HYRAX_HOST']}/concern/#{work.class.to_s.underscore}s/#{work.id}"
    # main_app.hyrax_generic_work_path(work.id, locale: 'en')
    message = I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_create.message', user_link: user_link,
                                                                                             transfer_link: transfer_link,
                                                                                             work_link: work_link)
    Hyrax::MessengerService.deliver(::User.batch_user, receiving_user, message,
                                    I18n.t('hyrax.notifications.proxy_deposit_request.transfer_on_create.subject'))
  end
end
