require 'rails_helper'

RSpec.describe Hyrax::Workflow::NotificationService do
  context 'class methods' do
    subject { described_class }

    it { is_expected.to respond_to(:deliver_on_action_taken) }
  end

  let(:entity) { Sipity::Entity.new }

  describe "#call" do
    # subject { instance.call }

    context "when the notification exists" do
      around do |example|
        class ConfirmationOfSubmittedToUlraCommittee
          def self.send_notification(notification); end
        end
        example.run
        Object.send(:remove_const, :ConfirmationOfSubmittedToUlraCommittee)
      end

      context "with no agents" do
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
          Sipity::Notification.new(name: "confirmation_of_submitted_to_ulra_committee",
                                   recipients: [recipient1, recipient2])
        end
        let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
        let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
        let(:instance) do
          described_class.new(entity: entity,
                              action: action,
                              comment: "A pleasant read",
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

        it "calls the notification" do
          expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { "to" => creator, 'cc' => advisors }))
          instance.call
        end     
      end

      context "with registered role" do
        let(:user_role) { Sipity::Role.new(name: 'registered') }
        let(:recipient1) do
          Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                            role: user_role)
        end
        let(:notification) do
          Sipity::Notification.new(name: "confirmation_of_submitted_to_ulra_committee",
                                   recipients: [recipient1])
        end
        let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
        let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
        let(:instance) do
          described_class.new(entity: entity,
                              action: action,
                              comment: "A pleasant read",
                              user: user)
        end

        let(:user_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: 'registered', proxy_for_type: 'Hyrax::Group') }
        let(:user) { [FactoryBot.create(:user)] }
        let(:user_rel) { double(ActiveRecord::Relation, to_ary: user_agent) }
        let(:hyrax_role) { instance_double(Role) }
        let(:notify_user) { [FactoryBot.create(:user)] }

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

        it "does not call the notification" do
          expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { "to" => [] }))
          instance.call
        end
      end

      context "with depositing role" do
        let(:user_role) { Sipity::Role.new(name: 'depositing') }
        let(:recipient1) do
          Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                            role: user_role)
        end
        let(:notification) do
          Sipity::Notification.new(name: "confirmation_of_submitted_to_ulra_committee",
                                   recipients: [recipient1])
        end
        let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
        let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
        let(:instance) do
          described_class.new(entity: entity,
                              action: action,
                              comment: "A pleasant read",
                              user: user)
        end

        let(:user_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: 'depositing', proxy_for_type: 'Hyrax::Group') }
        let(:user) { [FactoryBot.create(:user)] }
        let(:user_rel) { double(ActiveRecord::Relation, to_ary: user_agent) }
        let(:hyrax_role) { instance_double(Role) }
        let(:notify_user) { [FactoryBot.create(:user)] }

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

        it "does not call the notification" do
          expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { "to" => [] }))
          instance.call
        end
      end

      context "with admin agent" do
        let(:user) { [FactoryBot.create(:admin)] }
        let(:user_role) { Sipity::Role.new(name: 'admin') }
        let(:recipient1) do
          Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                            role: user_role)
        end
        let(:notification) do
          Sipity::Notification.new(name: "confirmation_of_submitted_to_ulra_committee",
                                   recipients: [recipient1])
        end
        let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
        let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
        let(:instance) do
          described_class.new(entity: entity,
                              action: action,
                              comment: "A pleasant read",
                              user: user)
        end

        let(:user_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: 'admin', proxy_for_type: 'Hyrax::Group') }
        let(:user_rel) { double(ActiveRecord::Relation, to_ary: user_agent) }
        let(:hyrax_role) { instance_double(Role) }
        let(:notify_user) { [FactoryBot.create(:user)] }

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

        it "does not call the notification" do
          expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { "to" => [] }))
          instance.call
        end
      end

      context "with reviewing role" do
        let(:user_role) { Sipity::Role.new(name: 'reviewing') }
        let(:recipient1) do
          Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                            role: user_role)
        end
        let(:notification) do
          Sipity::Notification.new(name: "confirmation_of_submitted_to_ulra_committee",
                                   recipients: [recipient1])
        end
        let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
        let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
        let(:instance) do
          described_class.new(entity: entity,
                              action: action,
                              comment: "A pleasant read",
                              user: user)
        end

        let(:user_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: 'reviewing', proxy_for_type: 'Hyrax::Group') }
        let(:user) { [FactoryBot.create(:user)] }
        let(:user_rel) { double(ActiveRecord::Relation, to_ary: user) }
        let(:hyrax_role) { instance_double(Role) }
        let(:notify_user) { [FactoryBot.create(:user)] }

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

        it "calls the notification" do
          expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { "to" => notify_user }))
          instance.call
        end
      end

      context "with agent proxy for user" do
        let(:user_role) { Sipity::Role.new(name: 'depositing') }
        let(:recipient1) do
          Sipity::NotificationRecipient.new(recipient_strategy: 'to',
                                            role: user_role)
        end
        let(:notification) do
          Sipity::Notification.new(name: "confirmation_of_submitted_to_ulra_committee",
                                   recipients: [recipient1])
        end
        let(:notifiable_context) { Sipity::NotifiableContext.new(notification: notification) }
        let(:action) { Sipity::WorkflowAction.new(notifiable_contexts: [notifiable_context]) }
        let(:instance) do
          described_class.new(entity: entity,
                              action: action,
                              comment: "A pleasant read",
                              user: user)
        end

        let(:user_agent) { Sipity::Agent.new(id: Date.today.to_time.to_i, proxy_for_id: 'depositing', proxy_for_type: 'User') }
        let(:user) { [FactoryBot.create(:user)] }
        let(:user_rel) { double(ActiveRecord::Relation, to_ary: user) }
        let(:notify_user) { [FactoryBot.create(:user)] }

        before do
          allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_users_for_entity_and_roles)
            .with(entity: entity,
                  roles: user_role)
            .and_return([])

          allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_agents_associated_with_entity_and_role)
            .with(entity: entity,
                  role: user_role)
            .and_return([user_agent])

          allow(::User).to receive(:find).with(user_agent.proxy_for_id).and_return(notify_user.first)
        end

        it "calls the notification" do
          expect(ConfirmationOfSubmittedToUlraCommittee).to receive(:send_notification).with(hash_including(recipients: { "to" => notify_user }))
          instance.call
        end
      end
    end
  end
end