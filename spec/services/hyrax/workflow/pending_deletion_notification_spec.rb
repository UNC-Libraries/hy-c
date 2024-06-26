# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Workflow::PendingDeletionNotification do
  let(:admin) { FactoryBot.create(:admin) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:cc_user) { FactoryBot.create(:user) }
  let(:work) { Article.create(title: ['New Article'], depositor: depositor.email) }
  let(:admin_set) do
    AdminSet.create(title: ['article admin set'],
                    description: ['some description'],
                    edit_users: [depositor.user_key])
  end
  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end
  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end
  let(:entity) { Sipity::Entity.create(proxy_for_global_id: work.to_global_id.to_s, workflow_id: workflow.id) }
  let(:comment) { double('comment', comment: 'A pleasant read') }

  describe '.send_notification' do
    before do
      User.delete_all
    end
    it 'sends a message to all users' do
      recipients = { 'to' => [depositor], 'cc' => [cc_user] }
      expect(depositor).to receive(:send_message)
        .with(anything, I18n.t('hyrax.notifications.workflow.deletion_pending.message', title: work.title[0],
                                                                                        work_id: work.id, document_path: "#{ENV['HYRAX_HOST']}/concern/articles/#{work.id}",
                                                                                        user: depositor, comment: comment.comment), anything).exactly(3).times.and_call_original
      expect { described_class.send_notification(entity: entity, user: depositor, comment: comment, recipients: recipients) }
        .to change { admin.mailbox.inbox.count }.by(1)
                                                .and change { depositor.mailbox.inbox.count }.by(1)
                                                                                             .and change { cc_user.mailbox.inbox.count }.by(1)
    end

    context 'without carbon-copied users' do
      it 'sends a message to the to user(s)' do
        recipients = { 'to' => [depositor], 'cc' => [] }
        expect(depositor).to receive(:send_message).exactly(2).times.and_call_original
        expect { described_class.send_notification(entity: entity, user: depositor, comment: comment, recipients: recipients) }
          .to change { admin.mailbox.inbox.count }.by(1)
                                                  .and change { depositor.mailbox.inbox.count }.by(1)
                                                                                               .and change { cc_user.mailbox.inbox.count }.by(0)
      end
    end
  end
end
