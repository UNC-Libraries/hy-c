# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create and review a work in the honors thesis workflow', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_user2) do
      User.new(email: 'admin2@example.com', guest: false, uid: 'admin2@example.com') { |u| u.save!(validate: false)}
    end

    let(:contact) do
      User.new(email: 'contact@example.com', guest: false, uid: 'contact@example.com') { |u| u.save!(validate: false)}
    end

    let(:manager) do
      User.new(email: 'manager@example.com', guest: false, uid: 'manager@example.com') { |u| u.save!(validate: false)}
    end

    let(:reviewer) do
      User.new(email: 'reviewer@example.com', guest: false, uid: 'reviewer@example.com') { |u| u.save!(validate: false)}
    end

    let(:nonreviewer) do
      User.new(email: 'nonreviewer@example.com', guest: false, uid: 'nonreviewer@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_set) do
      AdminSet.create(title: ["honors thesis admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key],
                      creator: [admin_user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end

    let(:workflow) { Sipity::Workflow.find_by!(name: 'honors_thesis_one_step_mediated_deposit', permission_template: permission_template) }
    let(:admin_agent) { Sipity::Agent.where(proxy_for_id: 'admin', proxy_for_type: 'Hyrax::Group').first_or_create }
    let(:admin_user_agent) { Sipity::Agent.where(proxy_for_id: admin_user.id, proxy_for_type: 'User').first_or_create }
    let(:contact_user_agent) { Sipity::Agent.where(proxy_for_id: contact.id, proxy_for_type: 'User').first_or_create }
    let(:manager_agent) { Sipity::Agent.where(proxy_for_id: 'honors_manager', proxy_for_type: 'Hyrax::Group').first_or_create }
    let(:reviewer_agent) { Sipity::Agent.where(proxy_for_id: reviewer.id, proxy_for_type: 'User').first_or_create }

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'manage')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: reviewer.user_key,
                                             access: 'manage')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: 'admin',
                                             access: 'manage')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'group',
                                             agent_id: 'honors_manager',
                                             access: 'manage')
      Hyrax::Workflow::WorkflowImporter.generate_from_json_file(path: Rails.root.join('config',
                                                                                      'workflows',
                                                                                      'honors_thesis_deposit_workflow.json'),
                                                                permission_template: permission_template)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: admin_user_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: admin_user_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'deleting', workflow: workflow, agents: admin_user_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: admin_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: admin_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'viewing', workflow: workflow, agents: contact_user_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'managing', workflow: workflow, agents: reviewer_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: reviewer_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: reviewer_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'managing', workflow: workflow, agents: manager_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: manager_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: manager_agent)

      permission_template.available_workflows.first.update!(active: true)
      DefaultAdminSet.create(work_type_name: 'HonorsThesis', admin_set_id: admin_set.id)
      role = Role.where(name: 'admin').first
      role.users << admin_user2
      role.save
      manager_role = Role.where(name: 'honors_manager').first_or_create
      manager_role.users << manager
      manager_role.save
    end

    scenario 'as a non-admin creates a work' do
      expect(admin_user.mailbox.inbox.count).to eq 0
      expect(admin_user2.mailbox.inbox.count).to eq 0
      expect(user.mailbox.inbox.count).to eq 0
      expect(reviewer.mailbox.inbox.count).to eq 0
      expect(nonreviewer.mailbox.inbox.count).to eq 0
      expect(manager.mailbox.inbox.count).to eq 0

      # Check that reviewer role does not yet exist
      login_as admin_user

      visit '/roles'
      expect(page).to have_content 'Admin'
      expect(page).not_to have_content 'department_of_biology_reviewer'

      click_on 'Logout'

      # Create work
      login_as user

      visit new_hyrax_honors_thesis_path
      expect(page).to have_content "Add New Undergraduate Honors Thesis"

      fill_in 'Title', with: 'Honors workflow test'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'honors_thesis_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'honors_thesis_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'honors_thesis_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'honors_thesis_creators_attributes_0_other_affiliation' }
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", from: "honors_thesis_rights_statement"
      expect(page).to have_field('honors_thesis_visibility_embargo')
      expect(page).not_to have_field('honors_thesis_visibility_lease')
      choose "honors_thesis_visibility_open"
      check 'agreement'

      expect(page).not_to have_selector('#honors_thesis_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'
      expect(page).to have_content 'Pending review'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      # Dept contact and user get notification for 'approving' role
      # Reviewer is not yet in reviewing group and does not get a notification
      expect(admin_user.mailbox.inbox.count).to eq 0
      expect(admin_user2.mailbox.inbox.count).to eq 0
      expect(contact.mailbox.inbox.count).to eq 0
      expect(user.mailbox.inbox.count).to eq 1
      expect(reviewer.mailbox.inbox.count).to eq 0
      expect(nonreviewer.mailbox.inbox.count).to eq 0
      expect(manager.mailbox.inbox.count).to eq 0

      click_on 'Logout'

      # Check that work is not yet visible to general public
      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Login'
      expect(page).to have_content 'Honors workflow test'
      expect(page).not_to have_content 'Review and Approval'
      expect(page).to have_content 'The work is not currently available because it has not yet completed the approval process'

      # Check that new role has been created
      login_as admin_user

      visit '/roles'
      expect(page).to have_content 'Admin'
      expect(page).to have_content 'department_of_biology_reviewer'

      # Add reviewer to role
      click_on 'department_of_biology_reviewer'
      fill_in 'User', with: contact.email
      click_button 'Add'
      expect(page).to have_content "Accounts: contact@example.com"

      click_on 'Logout'

      # Check that non-reviewer cannot review work
      login_as nonreviewer

      visit '/dashboard'
      expect(page).to have_content 'Your activity'
      expect(page).not_to have_content 'Review Submissions'

      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Honors workflow test'
      expect(page).not_to have_content 'Review and Approval'

      click_on 'Logout'

      # Check that department contact can review work
      login_as contact

      visit '/dashboard'
      # current functionality only allows approving role to see 'Review Submissions'
      # expect(page).to have_content 'Review Submissions'

      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Review and Approval'
      expect(page).not_to have_content 'Approve'
      expect(page).not_to have_content 'Request Changes'
      expect(page).to have_content 'Comment Only'

      expect(page).to have_content 'Public'
      expect(page).to have_content 'Pending review'
      expect(page).to have_content 'Honors workflow test'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      click_on 'Logout'

      # Check that a manager can review and approve work
      login_as manager

      visit '/dashboard'
      expect(page).to have_content 'Review Submissions'

      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Review and Approval'
      expect(page).to have_content 'Approve'
      expect(page).to have_content 'Request Changes'
      expect(page).to have_content 'Comment Only'

      expect(page).to have_content 'Public'
      expect(page).to have_content 'Pending review'
      expect(page).to have_content 'Honors workflow test'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      click_on 'Logout'

      # Check that reviewer can review work
      login_as reviewer

      visit '/dashboard'
      expect(page).to have_content 'Review Submissions'

      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Review and Approval'
      within '#workflow_controls' do
        choose 'Approve'
        click_button 'Submit'
      end

      expect(page).to have_content 'Public'
      expect(page).not_to have_content 'Pending review'
      expect(page).to have_content 'Deposited'
      expect(page).to have_content 'Honors workflow test'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'


      # User and admin set owner get notification for 'depositing' role
      expect(admin_user.mailbox.inbox.count).to eq 1
      expect(admin_user2.mailbox.inbox.count).to eq 0
      expect(contact.mailbox.inbox.count).to eq 0
      expect(user.mailbox.inbox.count).to eq 2
      expect(reviewer.mailbox.inbox.count).to eq 1
      expect(nonreviewer.mailbox.inbox.count).to eq 0
      expect(manager.mailbox.inbox.count).to eq 0

      click_on 'Logout'

      # Check notifications for tombstone requests
      login_as user

      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      click_on 'Request Deletion'

      within '#deletion-request-modal' do
        fill_in 'workflow_action_comment', with: 'delete me'
        click_button 'Submit'
      end

      expect(page).to have_content 'Pending deletion'

      # User gets notification for deletion requests
      expect(admin_user.mailbox.inbox.count).to eq 2
      expect(admin_user2.mailbox.inbox.count).to eq 0
      expect(contact.mailbox.inbox.count).to eq 0
      expect(user.mailbox.inbox.count).to eq 3
      expect(reviewer.mailbox.inbox.count).to eq 1
      expect(nonreviewer.mailbox.inbox.count).to eq 0
      expect(manager.mailbox.inbox.count).to eq 0

      # create a second honors thesis work to test viewer notification
      visit new_hyrax_honors_thesis_path
      expect(page).to have_content "Add New Undergraduate Honors Thesis"

      fill_in 'Title', with: 'Honors workflow test'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'honors_thesis_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'honors_thesis_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'honors_thesis_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'honors_thesis_creators_attributes_0_other_affiliation' }
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", from: "honors_thesis_rights_statement"
      expect(page).to have_field('honors_thesis_visibility_embargo')
      expect(page).not_to have_field('honors_thesis_visibility_lease')
      choose "honors_thesis_visibility_open"
      check 'agreement'

      expect(page).not_to have_selector('#honors_thesis_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'
      expect(page).to have_content 'Pending review'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      # User gets deposit notification
      expect(admin_user.mailbox.inbox.count).to eq 2
      expect(admin_user2.mailbox.inbox.count).to eq 0
      expect(contact.mailbox.inbox.count).to eq 1
      expect(user.mailbox.inbox.count).to eq 4
      expect(reviewer.mailbox.inbox.count).to eq 1
      expect(nonreviewer.mailbox.inbox.count).to eq 0
      expect(manager.mailbox.inbox.count).to eq 0

      click_on 'Logout'

      # Check that work is not yet visible to general public
      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Login'
      expect(page).to have_content 'Honors workflow test'
      expect(page).not_to have_content 'Review and Approval'
      expect(page).to have_content 'The work is not currently available because it has not yet completed the approval process'

      # Check that reviewer can review work
      login_as reviewer

      visit '/dashboard'
      expect(page).to have_content 'Review Submissions'

      visit '/concern/honors_theses/'+HonorsThesis.all[-1].id
      expect(page).to have_content 'Review and Approval'
      within '#workflow_controls' do
        choose 'Approve'
        click_button 'Submit'
      end
    end
  end
end
