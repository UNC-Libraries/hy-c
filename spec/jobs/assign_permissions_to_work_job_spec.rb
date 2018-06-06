require 'rails_helper'

RSpec.describe AssignPermissionsToWorkJob, type: :job do
  let(:user) { create(:user) }

  let(:admin_set) { AdminSet.create(title: ['an admin set']) }
  let(:permission_template) { Hyrax::PermissionTemplate.create(admin_set_id: admin_set.id) }
  let(:workflow) { Sipity::Workflow.create(name: 'a workflow', permission_template_id: permission_template.id, active: true)}
  let(:work) { HonorsThesis.create(title: ['a title'],
                                   depositor: 'admin@example.com',
                                   academic_concentration: ['biology'],
                                   admin_set_id: admin_set.id,
                                   visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE) }

  before(:each) do
    work
    workflow
  end

  context "a biology work is added" do
    it "and reviewer gets read access" do
      expect(work).to be_valid
      expect(work.read_groups).to eq([])
      described_class.perform_now(work.class.name, work.id, 'biology_reviewer', 'group', 'read')
      work.reload
      expect(work.read_groups).to eq(['biology_reviewer'])
    end
  end
end