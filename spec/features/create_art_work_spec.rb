# Generated via
#  `rails generate hyrax:work Art Work`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create an Art Work', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["art work admin set"],
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
      DefaultAdminSet.create(work_type_name: 'ArtWork', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_art_work_path
      expect(page).to have_content "Add New Art Work"

      # required fields
      fill_in 'Title', with: 'Test Art Work work'
      fill_in 'Date Created', with: '2018-10-03'
      fill_in 'Description', with: 'a description'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Medium', with: 'a medium'
      select 'Other', from: 'art_work_resource_type'

      # extra fields
      fill_in 'Doi', with: 'some doi'
      select 'Attribution 3.0 United States', :from => 'art_work_license'
      select 'In Copyright', :from => 'art_work_rights_statement'

      expect(page).to_not have_field('art_work_license_label')
      expect(page).to_not have_field('art_work_rights_statement_label')
      expect(page).to have_field('art_work_visibility_embargo')
      expect(page).not_to have_field('art_work_visibility_lease')
      choose "art_work_visibility_open"
      check 'agreement'

      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Art Work work'

      first('.document-title', text: 'Test Art Work work').click
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Resource type Other'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: art_work admin set'
      expect(page).to_not have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_art_work_path
      expect(page).to have_content "Add New Art Work"

      # required fields
      fill_in 'Title', with: 'Test Art Work work'
      fill_in 'Date Created', with: '2018-10-03'
      fill_in 'Description', with: 'a description'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Medium', with: 'a medium'
      select 'Other', from: 'art_work_resource_type'

      # extra fields
      fill_in 'Doi', with: 'some doi'
      select 'Attribution 3.0 United States', :from => 'art_work_license'
      select 'In Copyright', :from => 'art_work_rights_statement'

      expect(page).to_not have_field('art_work_license_label')
      expect(page).to_not have_field('art_work_rights_statement_label')
      expect(page).to have_field('art_work_visibility_embargo')
      expect(page).not_to have_field('art_work_visibility_lease')
      choose "art_work_visibility_open"
      check 'agreement'

      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Administrative Set'
      find('#art_work_admin_set_id').text eq 'art_work admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Art Work work'

      first('.document-title', text: 'Test Art Work work').click
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Resource type Other'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: art work admin set'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
