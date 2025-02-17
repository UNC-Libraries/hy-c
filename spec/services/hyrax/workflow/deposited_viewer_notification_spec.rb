# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Workflow::DepositedViewerNotification do
  let(:approver) { FactoryBot.create(:admin) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:cc_user) { FactoryBot.create(:user) }
  let(:work) { Article.create(title: ['New Article'], depositor: depositor.user_key) }
  let(:admin_set) do
    AdminSet.create(title: ['article admin set'],
                    description: ['some description'],
                    edit_users: [depositor.user_key])
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
    it 'sends a message to all users' do
      recipients = { 'to' => [depositor], 'cc' => [cc_user] }
      allow(ActiveFedora::SolrService).to receive(:get).with("id:#{work.id}", rows: 1).and_return('response' => { 'docs' => mock_solr_article })
      allow(ActiveFedora::SolrService).to receive(:get).with("title_tesim:#{admin_set.title} AND has_model_ssim:(\"AdminSet\")",  {'df'=>'title_tesim', :rows=>1}).and_return('response' => { 'docs' => mock_solr_admin_set })

      expect(approver).to receive(:send_message)
        .with(anything, I18n.t('hyrax.notifications.workflow.deposited_viewer.message', title: work.title[0],
                                                                                         link: "<a href=\"#{ENV['HYRAX_HOST']}/concern/articles/#{work.id}\">#{work.id}</a>"),
              anything).exactly(2).times.and_call_original

      expect { described_class.send_notification(entity: entity, user: approver, comment: comment, recipients: recipients) }
        .to change { depositor.mailbox.inbox.count }.by(1)
        .and change { cc_user.mailbox.inbox.count }.by(1)
        .and change { approver.mailbox.inbox.count }.by(0)
    end
  end
end
