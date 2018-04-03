# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a MastersPaper', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com',guest: false) { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["masters paper admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end

    let(:dept_admin_set) do
      AdminSet.create(title: ["dept admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(admin_set_id: admin_set.id)
    end

    let(:dept_permission_template) do
      Hyrax::PermissionTemplate.create!(admin_set_id: dept_admin_set.id)
    end

    let(:workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                              permission_template_id: permission_template.id)
    end

    let(:dept_workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                              permission_template_id: dept_permission_template.id)
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: dept_permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'deposit')
      Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
      Sipity::WorkflowAction.create(id: 5, name: 'show', workflow_id: dept_workflow.id)
      DefaultAdminSet.create(work_type_name: 'MastersPaper', admin_set_id: admin_set.id)
      DefaultAdminSet.create(work_type_name: 'MastersPaper',
                             department: 'College of Arts and Sciences, Department of Art, Art History Program',
                             admin_set_id: dept_admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit masters_papers_department_path
      expect(page).to have_content "Add New Masters Paper"
      select 'Art History Program', from: 'masters_paper_affiliation'
      click_on 'Select'

      expect(page).to have_content "Add New Masters Paper"

      fill_in 'Title', with: 'Test MastersPaper work'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", :from => "masters_paper_rights_statement"
      expect(page).to have_field('masters_paper_visibility_embargo')
      expect(page).not_to have_field('masters_paper_visibility_lease')
      choose "masters_paper_visibility_open"
      check 'agreement'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Add as member of administrative set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test MastersPaper work'

      first('.document-title', text: 'Test MastersPaper work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: dept admin set'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit masters_papers_department_path
      expect(page).to have_content "Add New Masters Paper"
      select 'Department of Chemistry', from: 'masters_paper_affiliation'
      click_on 'Select'

      expect(page).to have_content "Add New Masters Paper"

      fill_in 'Title', with: 'Test MastersPaper work'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", :from => "masters_paper_rights_statement"
      expect(page).to have_field('masters_paper_visibility_embargo')
      expect(page).not_to have_field('masters_paper_visibility_lease')
      choose "masters_paper_visibility_open"
      check 'agreement'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Add as member of administrative set'
      find('#masters_paper_admin_set_id').text eq 'masters paper admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test MastersPaper work'

      first('.document-title', text: 'Test MastersPaper work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: masters paper admin set'
    end
  end
end
