# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Workflow::DepositedViewerNotification do
  let(:approver) { FactoryBot.create(:admin) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:cc_user) { FactoryBot.create(:user) }
  let(:viewer1) { FactoryBot.create(:user) }
  let(:viewer2) { FactoryBot.create(:user) }
  let(:manager) { FactoryBot.create(:user) }

  let(:work) { Article.create(title: ['New Article'], depositor: depositor.user_key) }
  let(:admin_set) do
    AdminSet.create(title: ['article admin set'],
                    description: ['some description'],
                    edit_users: [depositor.user_key])
  end
  let(:mock_groups_and_roles) do
    [
      { 'user_id' => viewer1.id, 'email' => viewer1.email, 'group_name' => 'group1', 'admin_set_role' => 'view' },
      { 'user_id' => approver.id, 'email' => approver.email, 'group_name' => 'group1', 'admin_set_role' => 'manage' },
      { 'user_id' => manager.id, 'email' => manager.email, 'group_name' => 'group1', 'admin_set_role' => 'view' }
    ]
  end

  let(:mock_users_and_roles) do
    [
      { 'id' => viewer2.id, 'email' => viewer2.email, 'admin_set_role' => 'view' },
      { 'id' => manager.id, 'email' => manager.email, 'admin_set_role' => 'manage' }
    ]
  end
  let(:mock_solr_article) { [{
    'has_model_ssim' => ['Article'],
    'id' =>  work.id,
    'title_tesim' => [work.title[0]],
    'admin_set_tesim' => [admin_set.title]}]
  }
  let(:mock_solr_admin_set) { [{
  'has_model_ssim' => ['AdminSet'],
  'id' => 'h128zk07m',
  'title_tesim' => [admin_set.title]}
]
  }
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
    it 'sends a message to viewers and cc' do
      recipients = { 'to' => [], 'cc' => [cc_user] }
      allow(ActiveFedora::SolrService).to receive(:get).with("id:#{work.id}", rows: 1).and_return('response' => { 'docs' => mock_solr_article })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set.title} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_solr_admin_set })
      allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original  # Allow real DB transactions
      allow(ActiveRecord::Base.connection).to receive(:execute).with(/FROM users u\s+JOIN roles_users/).and_return(mock_groups_and_roles)
      allow(ActiveRecord::Base.connection).to receive(:execute).with(/FROM users u\s+JOIN permission_template_accesses/).and_return(mock_users_and_roles)

      expect(approver).to receive(:send_message)
        .with(anything, I18n.t('hyrax.notifications.workflow.deposited_manager.message', title: work.title[0],
                                                                                         link: "<a href=\"#{ENV['HYRAX_HOST']}/concern/articles/#{work.id}\">#{work.id}</a>"),
              anything).exactly(3).times.and_call_original

      expect { described_class.send_notification(entity: entity, user: approver, comment: comment, recipients: recipients) }
        .to change { depositor.mailbox.inbox.count }.by(0)
        .and change { approver.mailbox.inbox.count }.by(0)
        # Users assigned both the manager and viewer role should not be notified
        .and change { manager.mailbox.inbox.count }.by(0)
        .and change { cc_user.mailbox.inbox.count }.by(1)
        .and change { viewer1.mailbox.inbox.count }.by(1)
        .and change { viewer2.mailbox.inbox.count }.by(1)
    end
  end
end
