# [hyc-override] Overriding abstract notification service from gem
module Hyrax
  module Workflow
    class AbstractNotification
      include ActionView::Helpers::UrlHelper

      def self.send_notification(entity:, comment:, user:, recipients:)
        new(entity, comment, user, recipients).call
      end

      attr_reader :work_id, :title, :comment, :user, :recipients

      # @param [Sipity::Entity] entity - the Sipity::Entity that is a proxy for the relevant Hyrax work
      # @param [#comment] comment - the comment associated with the action being taken, could be a Sipity::Comment, or anything that responds to a #comment method
      # @param [Hyrax::User] user - the user who has performed the relevant action
      # @param [Hash] recipients - a hash with keys "to" and (optionally) "cc"
      # @option recipients [Array<Hyrax::User>] :to a list of users to which to send the notification
      # @option recipients [Array<Hyrax::User>] :cc a list of users to which to copy on the notification
      def initialize(entity, comment, user, recipients)
        @work_id = entity.proxy_for_global_id.sub(/.*\//, '')
        @title = entity.proxy_for.title.first
        @comment = comment.respond_to?(:comment) ? comment.comment.to_s : ''
        # Convert to hash with indifferent access to allow both string and symbol keys
        @recipients = recipients.with_indifferent_access
        @user = user
        @entity = entity
      end

      def call
        users_to_notify.uniq.each do |recipient|
          if ENV['ALLOW_NOTIFICATIONS']
            Hyrax::MessengerService.deliver(user, recipient, message, subject)
          else
            Rails.logger.info "\nNot sending messages\n"
          end
        end
      end

      private

      def subject
        raise NotImplementedError, 'Implement #subject in a child class'
      end

      def message
        I18n.t('hyrax.notifications.workflow.review_advanced.message', title: title, work_id: work_id,
                                                                       document_path: document_path, user: user, comment: comment)
      end

      # @return [ActiveFedora::Base] the document (work) the the Abstract WorkFlow is creating a notification for
      def document
        @entity.proxy_for
      end

      # [hyc-override] Overriding document_path method to return full url instead of the relative path
      # Replacing "_path" with "_url"
      def document_path
        key = document.model_name.singular_route_key
        Rails.application.routes.url_helpers.send("#{key}_url", document.id)
      end

      def users_to_notify
        recipients.fetch(:to, []) + recipients.fetch(:cc, [])
      end
    end
  end
end
