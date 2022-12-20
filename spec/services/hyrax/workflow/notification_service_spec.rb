# frozen_string_literal: true
require 'rails_helper'
require 'active_fedora/cleaner'
# Load the override being tested
require Rails.root.join('app/overrides/services/hyrax/workflow/notification_service_override.rb')

RSpec.describe Hyrax::Workflow::NotificationService do
  let(:entity) { Sipity::Entity.new }

  describe '#call' do
    around do |example|
      class ConfirmationOfSubmittedToUlraCommittee
        def self.send_notification(notification); end
      end
      example.run
      Object.send(:remove_const, :ConfirmationOfSubmittedToUlraCommittee)
    end

    before do
      ActiveFedora::Cleaner.clean!
    end

    # Check that base behavior
    context 'with no agents' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:creating_user) { Sipity::Role.new(name: 'creating_user') }
      let(:recipient1) do
        Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                          role: creating_user)
      end
      let(:advising) { Sipity::Role.new(name: 'advising') }
      let(:recipient2) do
        Sipity::NotificationRecipient.new(recipient_strategy: 'cc',
                                          role: advising)
      end
      let(:notification) do
        Sipity::Notification.new(name: 'confirmation_of_submitted_to_ulra_committee',
                                 recipients: [recipient1, recipient2])
      end
      let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
      let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
      let(:instance) do
        described_class.new(entity: entity,
                            action: action,
                            comment: 'A pleasant read',
                            user: user)
      end

      let(:advisors) { [FactoryBot.create(:user), FactoryBot.create(:user)] }
      let(:creator) { [FactoryBot.create(:user)] }
      let(:advisor_rel) { double(ActiveRecord::Relation, to_ary: advisors) }
      let(:creator_rel) { double(ActiveRecord::Relation, to_ary: creator) }

      before do
        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_users_for_entity_and_roles)
          .with(entity: entity,
                roles: advising)
          .and_return(advisor_rel)

        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_users_for_entity_and_roles)
          .with(entity: entity,
                roles: creating_user)
          .and_return(creator_rel)
      end

      it 'calls the notification' do
        expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { 'to' => creator, 'cc' => advisors }))
        instance.call
      end
    end

    RSpec.shared_examples 'sends notification recipients' do |role_name, proxy_for_type|
      let(:user_role) { Sipity::Role.new(name: role_name) }
      let(:recipient1) do
        Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                          role: user_role)
      end
      let(:notification) do
        Sipity::Notification.new(name: 'confirmation_of_submitted_to_ulra_committee',
                                 recipients: [recipient1])
      end
      let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
      let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
      let(:instance) do
        described_class.new(entity: entity,
                            action: action,
                            comment: 'A pleasant read',
                            user: user)
      end

      let(:user_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: role_name, proxy_for_type: proxy_for_type) }
      let(:user_rel) { double(ActiveRecord::Relation, to_ary: user_agent) }
      let(:hyrax_role) { instance_double(Role) }

      before do
        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_users_for_entity_and_roles)
          .with(entity: entity,
                roles: user_role)
          .and_return([])

        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_agents_associated_with_entity_and_role)
          .with(entity: entity,
                role: user_role)
          .and_return([user_agent])

        allow(hyrax_role).to receive(:users).and_return(notify_user)
        allow(Role).to receive(:where).with(name: user_role.name).and_return([hyrax_role])
      end

      it 'calls the notification' do
        expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: expected_recipients))
        instance.call
      end
    end

    it_behaves_like 'sends notification recipients', 'registered', 'Hyrax::Group' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      let(:expected_recipients) { { 'to' => [] } }
    end

    it_behaves_like 'sends notification recipients', 'registered', 'Role' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      let(:expected_recipients) { { 'to' => [] } }
    end

    it_behaves_like 'sends notification recipients', 'depositing', 'Role' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      let(:expected_recipients) { { 'to' => [] } }
    end

    it_behaves_like 'sends notification recipients', 'admin', 'Hyrax::Group' do
      let(:user) { [FactoryBot.create(:admin)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      let(:expected_recipients) { { 'to' => [] } }
    end

    it_behaves_like 'sends notification recipients', 'reviewing', 'Hyrax::Group' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      let(:expected_recipients) { { 'to' => notify_user } }
    end

    it_behaves_like 'sends notification recipients', 'reviewing', 'Role' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      let(:expected_recipients) { { 'to' => notify_user } }
    end

    # Recipient associated with User agent type
    it_behaves_like 'sends notification recipients', 'depositing', 'User' do
      let(:user) { [FactoryBot.create(:user)] }
      let(:notify_user) { [FactoryBot.create(:user)] }
      # Add second notification user that is not returned by the Role query
      let(:notify_user2) { [FactoryBot.create(:user)] }

      before do
        allow(::User).to receive(:find).with(user_agent.proxy_for_id).and_return(notify_user2.first)
      end

      let(:expected_recipients) { { 'to' => notify_user2 } }
    end
  end
end
