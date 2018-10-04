# Generated via
#  `rails generate hyrax:work Multimed`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a Multimed', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["default admin set"],
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
      DefaultAdminSet.create(work_type_name: 'Multimed', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_multimed_path
      expect(page).to have_content "Add New Multimedia"

      # required fields
      fill_in 'Title', with: 'Test Multimed'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Date Created', with: '2018-10-03'
      select 'Video', from: 'multimed_resource_type'

      # extra fields
      fill_in 'Doi', with: 'some doi'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Geographic subject', with: 'some geographic subject'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'multimed_language'
      select 'Attribution 3.0 United States', :from => 'multimed_license'
      fill_in 'Medium', with: 'a medium'
      fill_in 'Note', with: 'a note'
      fill_in 'Orcid', with: 'an orcid'
      select 'In Copyright', :from => 'multimed_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).to have_field('multimed_visibility_embargo')
      expect(page).not_to have_field('multimed_visibility_lease')
      choose "multimed_visibility_open"
      check 'agreement'
      
      expect(page).not_to have_selector('#multimed_dcmi_type')

      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Multimed'

      first('.document-title', text: 'Test Multimed').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Creator Test Default Creator'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Geographic subject some geographic subject'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Orcid an orcid'
      expect(page).to have_content 'Resource type Video'
      expect(page).to have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'
      expect(page).to have_content 'Subject test'

      expect(page).to_not have_content 'In Administrative Set: general admin set'
      expect(page).to_not have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_multimed_path
      expect(page).to have_content "Add New Multimedia"

      # required fields
      fill_in 'Title', with: 'Test Multimed'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Date Created', with: '2018-10-03'
      select 'Video', from: 'multimed_resource_type'

      # extra fields
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Text'
      fill_in 'Doi', with: 'some doi'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Geographic subject', with: 'some geographic subject'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'multimed_language'
      select 'Attribution 3.0 United States', :from => 'multimed_license'
      fill_in 'Medium', with: 'a medium'
      fill_in 'Note', with: 'a note'
      fill_in 'Orcid', with: 'an orcid'
      select 'In Copyright', :from => 'multimed_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).to have_field('multimed_visibility_embargo')
      expect(page).not_to have_field('multimed_visibility_lease')
      choose "multimed_visibility_open"
      check 'agreement'

      expect(page).to have_selector('#multimed_dcmi_type')

      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Administrative Set'
      find('#multimed_admin_set_id').text eq 'default admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Multimed'

      first('.document-title', text: 'Test Multimed').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Creator Test Default Creator'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Geographic subject some geographic subject'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Orcid an orcid'
      expect(page).to have_content 'Resource type Video'
      expect(page).to have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'
      expect(page).to have_content 'Subject test'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
