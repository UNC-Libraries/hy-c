# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a HonorsThesis', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["honors thesis admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end

    let(:workflow) { Sipity::Workflow.find_by!(name: 'default', permission_template: permission_template) }

    let(:admin_agent) { Sipity::Agent.where(proxy_for_id: admin_user.id, proxy_for_type: 'User').first_or_create }
    let(:user_agent) { Sipity::Agent.where(proxy_for_id: user.id, proxy_for_type: 'User').first_or_create }

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'deposit')
      Hyrax::Workflow::WorkflowImporter.generate_from_json_file(path: Rails.root.join('config',
                                                                                      'workflows',
                                                                                      'default_workflow.json'),
                                                                permission_template: permission_template)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: user_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: user_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: admin_agent)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: admin_agent)
      permission_template.available_workflows.first.update!(active: true)
      DefaultAdminSet.create(work_type_name: 'HonorsThesis', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_honors_thesis_path
      expect(page).to have_content "Add New Undergraduate Honors Thesis"

      fill_in 'Title', with: 'Test HonorsThesis work'
      fill_in 'Author', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Department of Biology', from: 'honors_thesis_affiliation'
      select "In Copyright", :from => "honors_thesis_rights_statement"
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

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test HonorsThesis work'

      first('.document-title', text: 'Test HonorsThesis work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to_not have_content 'In Administrative Set: honors thesis admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_content 'Affiliation'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_honors_thesis_path
      expect(page).to have_content "Add New Undergraduate Honors Thesis"

      fill_in 'Title', with: 'Test HonorsThesis work'
      fill_in 'Author', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Department of Biology', from: 'honors_thesis_affiliation'
      select "In Copyright", :from => "honors_thesis_rights_statement"
      expect(page).to have_field('honors_thesis_visibility_embargo')
      expect(page).not_to have_field('honors_thesis_visibility_lease')
      choose "honors_thesis_visibility_open"
      check 'agreement'
      
      expect(page).to have_selector('#honors_thesis_dcmi_type')
      expect(page).to have_selector("input[value='http://purl.org/dc/dcmitype/Text']")
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Image'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Administrative Set'
      find('#honors_thesis_admin_set_id').text eq 'honors thesis admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test HonorsThesis work'

      first('.document-title', text: 'Test HonorsThesis work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: honors thesis admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Image'
      expect(page).to have_content 'Affiliation'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
