# Generated via
#  `rails generate hyrax:work ScholarlyWork`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a ScholarlyWork', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["scholarly work admin set"],
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
      DefaultAdminSet.create(work_type_name: 'ScholarlyWork', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_scholarly_work_path
      expect(page).to have_content "Add New Scholarly Work"

      # required fields
      fill_in 'Title', with: 'Test ScholarlyWork work'
      fill_in 'Name', { with: 'Test Default Creator', id: 'scholarly_work_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'scholarly_work_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'scholarly_work_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'scholarly_work_creators_attributes_0_other_affiliation' }
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Date of publication', with: '2018-10-03'

      # extra fields
      fill_in 'Name', { with: 'advisor', id: 'scholarly_work_advisors_attributes_0_name' }
      fill_in 'ORCID', { with: 'advisor orcid', id: 'scholarly_work_advisors_attributes_0_orcid' }
      select 'Department of Biology', from: 'scholarly_work_advisors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'scholarly_work_advisors_attributes_0_other_affiliation' }
      fill_in 'Conference name', with: 'a conference'
      fill_in 'Description', with: 'a description'
      fill_in 'Location', with: 'some geographic subject'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'scholarly_work_language'
      select 'Attribution 3.0 United States', :from => 'scholarly_work_license'
      select 'Other', from: 'scholarly_work_resource_type'
      select 'In Copyright', :from => 'scholarly_work_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).not_to have_field('scholarly_work_date_created')
      expect(page).to have_selector('#scholarly_work_language_label', visible: false)
      expect(page).to have_selector('#scholarly_work_license_label', visible: false)
      expect(page).to have_selector('#scholarly_work_rights_statement_label', visible: false)
      expect(page).not_to have_field('scholarly_work_doi')
      expect(page).not_to have_field('scholarly_work_visibility_use')
      expect(page).to have_field('scholarly_work_visibility_embargo')
      expect(page).not_to have_field('scholarly_work_visibility_lease')
      choose "scholarly_work_visibility_open"
      check 'agreement'
      
      # Verify that admin only field is not visible
      expect(page).not_to have_selector('#scholarly_work_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test ScholarlyWork work'

      first('.document-title', text: 'Test ScholarlyWork work').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Advisor advisor ORCID: advisor orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Conference name a conference'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'Location some geographic subject'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Resource type Other'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: scholarly work admin set'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_scholarly_work_path
      expect(page).to have_content "Add New Scholarly Work"

      # required fields
      fill_in 'Title', with: 'Test ScholarlyWork work'
      fill_in 'Name', { with: 'Test Default Creator', id: 'scholarly_work_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'scholarly_work_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'scholarly_work_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'scholarly_work_creators_attributes_0_other_affiliation' }
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Date of publication', with: '2018-10-03'

      # extra fields
      fill_in 'Name', { with: 'advisor', id: 'scholarly_work_advisors_attributes_0_name' }
      fill_in 'ORCID', { with: 'advisor orcid', id: 'scholarly_work_advisors_attributes_0_orcid' }
      select 'Department of Biology', from: 'scholarly_work_advisors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'scholarly_work_advisors_attributes_0_other_affiliation' }
      fill_in 'Conference name', with: 'a conference'
      fill_in 'Date created', with: '2018-10-03'
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Text'
      fill_in 'Description', with: 'a description'
      fill_in 'DOI', with: 'some doi'
      fill_in 'Location', with: 'some geographic subject'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'scholarly_work_language'
      select 'Attribution 3.0 United States', :from => 'scholarly_work_license'
      select 'Other', from: 'scholarly_work_resource_type'
      select 'In Copyright', :from => 'scholarly_work_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).to have_selector('#scholarly_work_language_label', visible: false)
      expect(page).to have_selector('#scholarly_work_license_label', visible: false)
      expect(page).to have_selector('#scholarly_work_rights_statement_label', visible: false)
      expect(page).to have_field('scholarly_work_visibility_embargo')
      expect(page).not_to have_field('scholarly_work_visibility_lease')
      choose "scholarly_work_visibility_open"
      check 'agreement'
      
      expect(page).to have_selector('#scholarly_work_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to have_content 'Administrative Set'
      find('#scholarly_work_admin_set_id').text eq 'scholarly work admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test ScholarlyWork work'

      first('.document-title', text: 'Test ScholarlyWork work').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Advisor advisor ORCID: advisor orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Conference name a conference'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'DOI some doi'
      expect(page).to have_content 'Location some geographic subject'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Resource type Other'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: scholarly work admin set'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
