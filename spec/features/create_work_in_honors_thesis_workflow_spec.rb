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

    let(:reviewer) do
      User.new(email: 'reviewer@example.com', guest: false, uid: 'reviewer@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_set) do
      AdminSet.create(title: ["honors thesis admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end

    let(:honors_workflow) do
      {
          workflows: [
              {
                  name: 'honors',
                  label: 'One-step mediated deposit workflow for Honors Theses',
                  description: 'A single-step workflow for honors thesis mediated deposit in which all deposits must be'+
                      ' approved by an assigned reviewer. Reviewer may also send deposits back to the depositor.',
                  allows_access_grant: false,
                  actions: [
                      {
                          name: 'deposit',
                          from_states: [],
                          transition_to: 'pending_review',
                          methods: [
                              'Hyrax::Workflow::DeactivateObject',
                              'Hyrax::Workflow::AssignReviewerByAffiliation'
                          ]
                      }, {
                          name: 'request_changes',
                          from_states: [{names: ['deposited', 'pending_review'], roles: ['approving']}],
                          transition_to: 'changes_required',
                          methods: [
                              'Hyrax::Workflow::DeactivateObject',
                              'Hyrax::Workflow::GrantEditToDepositor'
                          ]
                      }, {
                          name: 'approve',
                          from_states: [{names: ['pending_review'], roles: ['approving']}],
                          transition_to: 'deposited',
                          methods: [
                              'Hyrax::Workflow::GrantReadToDepositor',
                              'Hyrax::Workflow::RevokeEditFromDepositor',
                              'Hyrax::Workflow::ActivateObject'
                          ]
                      }, {
                          name: 'request_review',
                          from_states: [{names: ['changes_required'], roles: ['depositing']}],
                          transition_to: 'pending_review',
                      }, {
                          name: 'comment_only',
                          from_states: [
                              { names: ['pending_review', 'deposited'], roles: ['approving'] },
                              { names: ['changes_required'], roles: ['depositing'] }
                          ]
                      }, {
                          name: 'tombstone',
                          from_states: [{names: ['deposited'], roles: ['approving']}],
                          transition_to: 'tombstoned',
                          methods: [
                             'Hyrax::Workflow::MetadataOnlyRecord'
                          ]
                      }, {
                          name: 'request_deletion',
                          from_states: [{names: ['deposited'], roles: ['approving', 'depositing']}],
                          transition_to: 'pending_deletion',
                          methods: [
                              'Hyrax::Workflow::RevokeEditFromDepositor'
                          ]
                      }, {
                          name: 'approve_deletion',
                          from_states: [{names: ['pending_deletion'], roles: ['approving']}],
                          transition_to: 'tombstoned',
                          methods: [
                              'Hyrax::Workflow::MetadataOnlyRecord'
                          ]
                      }, {
                          name: 'republish',
                          from_states: [{names: ['pending_deletion'], roles: ['approving']}],
                          transition_to: 'deposited',
                          methods: [
                              'Hyrax::Workflow::GrantEditToDepositor',
                              'Hyrax::Workflow::ActivateObject'
                          ]
                      }
                  ]
              }
          ]
      }
    end

    let(:workflow) { Sipity::Workflow.find_by!(name: 'honors', permission_template: permission_template) }
    let(:admin_agent) { Sipity::Agent.where(proxy_for_id: 'admin', proxy_for_type: 'Hyrax::Group').first_or_create }

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'manage')
      Hyrax::Workflow::WorkflowImporter.generate_from_hash(data: honors_workflow, permission_template: permission_template)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: admin_user)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: admin_agent)
      permission_template.available_workflows.first.update!(active: true)
      DefaultAdminSet.create(work_type_name: 'HonorsThesis', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin creates a work' do
      # Check that reviewer role does not yet exist
      login_as admin_user

      visit '/roles'
      expect(page).to have_content 'Admin'
      expect(page).not_to have_content 'department_of_biology_reviewer'

      logout admin_user

      # Create work
      login_as user

      visit new_hyrax_honors_thesis_path
      expect(page).to have_content "Add New Undergraduate Honors Thesis"

      fill_in 'Title', with: 'Honors workflow test'
      fill_in 'Author', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Department of Biology', from: 'Affiliation'
      select "In Copyright", from: "honors_thesis_rights_statement"
      expect(page).to have_field('honors_thesis_visibility_embargo')
      expect(page).not_to have_field('honors_thesis_visibility_lease')
      choose "honors_thesis_visibility_open"
      check 'agreement'

      expect(page).not_to have_selector('#honors_thesis_dcmi_type')

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'
      expect(page).to have_content 'Pending review'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: honors thesis admin set'
      expect(page).to have_content 'Affiliation College of Arts and Sciences, Department of Biology'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'

      logout user

      # Check that new role has been created
      login_as admin_user

      visit '/roles'
      expect(page).to have_content 'Admin'
      expect(page).to have_content 'department_of_biology_reviewer'

      # Add reviewer to role
      click_on 'department_of_biology_reviewer'
      fill_in 'User', with: reviewer.email
      click_button 'Add'
      expect(page).to have_content "Accounts: reviewer@example.com"

      logout admin_user

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
      expect(page).to have_content 'Honors workflow test'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: honors thesis admin set'
      expect(page).to have_content 'Affiliation College of Arts and Sciences, Department of Biology'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'
    end
  end
end
