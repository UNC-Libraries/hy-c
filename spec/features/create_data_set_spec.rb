# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a DataSet', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["data set admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end

    let(:workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                              permission_template_id: permission_template.id)
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'deposit')
      Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
      DefaultAdminSet.create(work_type_name: 'DataSet', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_data_set_path
      expect(page).to have_content "Add New Dataset"

      fill_in 'Title', with: 'Test Data Set'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'

      expect(page).not_to have_field('data_set_rights_statement')
      expect(page).to have_field('data_set_visibility_embargo')
      expect(page).not_to have_field('data_set_visibility_lease')
      choose "data_set_visibility_open"
      check 'agreement'
      
      expect(page).not_to have_selector('#data_set_dcmi_type')

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Data Set'

      first('.document-title', text: 'Test Data Set').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to_not have_content 'In Administrative Set: data set admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Dataset'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_data_set_path
      expect(page).to have_content "Add New Dataset"

      fill_in 'Title', with: 'Test Data Set'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'

      expect(page).not_to have_field('data_set_rights_statement')
      expect(page).to have_field('data_set_visibility_embargo')
      expect(page).not_to have_field('data_set_visibility_lease')
      choose "data_set_visibility_open"
      check 'agreement'
      
      expect(page).to have_selector('#data_set_dcmi_type')
      expect(page).to have_selector("input[value='http://purl.org/dc/dcmitype/Dataset']")
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Image'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Administrative Set'
      find('#data_set_admin_set_id').text eq 'data set admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Data Set'

      first('.document-title', text: 'Test Data Set').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: data set admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Image'
    end
  end
end
