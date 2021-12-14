require 'rails_helper'

RSpec.describe AssignPermissionsToWorkJob, type: :job do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:reviewer1) { User.create(email: 'reviewer1@example.com', uid: 'reviewer1', password: 'password', password_confirmation: 'password') }
  let(:reviewer2) { User.create(email: 'reviewer2@example.com', uid: 'reviewer2', password: 'password', password_confirmation: 'password') }
  let(:role) { Role.new(name: 'biology_reviewer') }
  let(:admin_set) { AdminSet.create(title: ['an admin set']) }
  let(:permission_template) { Hyrax::PermissionTemplate.create(source_id: admin_set.id) }
  let(:workflow) { Sipity::Workflow.create(name: 'a workflow', permission_template_id: permission_template.id, active: true)}
  let(:work) { HonorsThesis.create(title: ['a title'],
                                   depositor: 'admin',
                                   creators_attributes: { '0' => { name: 'creator',
                                                                   orcid: 'creator orcid',
                                                                   affiliation: 'biology',
                                                                   other_affiliation: 'another affiliation'} },
                                   admin_set_id: admin_set.id,
                                   visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
  }  
  let(:entity) { Sipity::Entity.create(workflow_id: workflow.id,proxy_for_global_id: work.to_global_id.to_s) }

  before(:each) do
    role.users << reviewer1
    role.users << reviewer2
    role.save
    entity
  end

  context "a biology work is added" do
    it "and reviewer gets read access" do
      expect(work).to be_valid
      expect(work.read_groups).to eq([])
      expect{ described_class.perform_now(work.class.name, work.id, role.name, 'group', 'read') }
          .to change{ reviewer1.mailbox.inbox.count }.by(1)
                  .and change { reviewer2.mailbox.inbox.count }.by(1)
      work.reload
      expect(work.read_groups).to eq([role.name])
    end
  end
end