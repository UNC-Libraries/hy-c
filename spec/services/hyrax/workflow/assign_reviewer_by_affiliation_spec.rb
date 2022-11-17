# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::Workflow::AssignReviewerByAffiliation do
  before do
    ActiveFedora::Cleaner.clean!
  end

  let!(:reviewer1) { FactoryBot.create(:user) }
  let!(:reviewer2) { FactoryBot.create(:user) }
  let!(:admin) { FactoryBot.create(:admin) }
  let(:admin_set) { AdminSet.create(title: ['an admin set']) }
  let(:permission_template) { Hyrax::PermissionTemplate.create(source_id: admin_set.id) }
  let(:workflow) { Sipity::Workflow.create(name: 'a workflow', permission_template_id: permission_template.id, active: true) }
  let(:work) {
    HonorsThesis.create(title: ['a title'],
                        depositor: admin.user_key,
                        creators_attributes: { '0' => { name: 'creator',
                                                        orcid: 'creator orcid',
                                                        affiliation: 'biology2',
                                                        other_affiliation: 'another affiliation' } },
                        admin_set_id: admin_set.id,
                        visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
  }
  let!(:entity) { Sipity::Entity.create(workflow_id: workflow.id, proxy_for_global_id: work.to_global_id.to_s) }

  describe ".call" do
    context 'with reviewers assigned to role' do
      let(:role) { Role.new(name: 'biology2_reviewer') }
      before(:each) do
        role.users << reviewer1
        role.users << reviewer2
        role.save
      end

      it "assigns reviewer group and sends notifications" do
        expect(work).to be_valid
        expect { described_class.call(target: work) }
          .to change { reviewer1.mailbox.inbox.count }.by(1)
          .and change { reviewer2.mailbox.inbox.count }.by(1)
          .and change { Sipity::EntitySpecificResponsibility.count }.by(1)
      end
    end
    context 'without reviewers assigned to role' do
      it "assigns reviewer group, does not send notifications" do
        expect(work).to be_valid
        expect { described_class.call(target: work) }
          .to change { reviewer1.mailbox.inbox.count }.by(0)
          .and change { reviewer2.mailbox.inbox.count }.by(0)
          .and change { Sipity::EntitySpecificResponsibility.count }.by(1)
      end
    end
  end
end