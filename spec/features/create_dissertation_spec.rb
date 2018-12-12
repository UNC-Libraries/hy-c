# Generated via
#  `rails generate hyrax:work Dissertation`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Create a Dissertation', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ['dissertation admin set'],
                      description: ['some description'],
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
      DefaultAdminSet.create(work_type_name: 'Dissertation', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_dissertation_path
      expect(page).to have_content 'You are not authorized to access this page'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_dissertation_path
      expect(page).to have_content 'Add New Dissertation or Thesis'

      # required fields
      fill_in 'Title', with: 'Test Dissertation work'
      fill_in 'Name', { with: 'Test Default Creator', id: 'dissertation_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'dissertation_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'dissertation_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'dissertation_creators_attributes_0_other_affiliation' }
      fill_in 'Date of publication', with: '2018-10-03'
      fill_in 'Degree granting institution', with: 'UNC'

      # extra fields
      fill_in 'Abstract', with: 'some abstract'
      select 'Clinical Nutrition', from: 'Academic Concentration'
      fill_in 'Name', { with: 'advisor', id: 'dissertation_advisors_attributes_0_name' }
      fill_in 'ORCID', { with: 'advisor orcid', id: 'dissertation_advisors_attributes_0_orcid' }
      select 'Department of Biology', from: 'dissertation_advisors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'dissertation_advisors_attributes_0_other_affiliation' }
      fill_in 'Alternate title', with: 'another title'
      fill_in 'Name', { with: 'contributor', id: 'dissertation_contributors_attributes_0_name' }
      fill_in 'ORCID', { with: 'contributor orcid', id: 'dissertation_contributors_attributes_0_orcid' }
      select 'Department of Biology', from: 'dissertation_contributors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'dissertation_contributors_attributes_0_other_affiliation' }
      select 'Bachelor of Science', from: 'dissertation_degree'
      fill_in 'DOI', with: 'some doi'
      select 'Dissertation', from: 'dissertation_resource_type'
      fill_in 'Access', with: 'some access'
      fill_in 'Location', with: 'some geographic subject'
      fill_in 'Graduation year', with: '2018'
      fill_in 'Identifier', with: 'some id'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'dissertation_language'
      select 'Attribution 3.0 United States', :from => 'dissertation_license'
      fill_in 'Note', with: 'a note'
      fill_in 'Place of publication', with: 'UNC'
      fill_in 'Publisher', with: 'UNC Press'
      fill_in 'Name', { with: 'reviewer', id: 'dissertation_reviewers_attributes_0_name' }
      fill_in 'ORCID', { with: 'reviewer orcid', id: 'dissertation_reviewers_attributes_0_orcid' }
      select 'Department of Biology', from: 'dissertation_reviewers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'dissertation_reviewers_attributes_0_other_affiliation' }
      select 'In Copyright', :from => 'dissertation_rights_statement'
      fill_in 'Subject', with: 'test'
      fill_in 'Use', with: 'some use'

      expect(page).to have_selector('#dissertation_language_label', visible: false)
      expect(page).to have_selector('#dissertation_license_label', visible: false)
      expect(page).to have_selector('#dissertation_rights_statement_label', visible: false)
      expect(page).to have_field('dissertation_visibility_embargo')
      expect(page).not_to have_field('dissertation_visibility_lease')
      choose 'dissertation_visibility_open'
      check 'agreement'
      
      expect(page).to have_selector('#dissertation_dcmi_type')
      expect(page).to have_selector("input[value='http://purl.org/dc/dcmitype/Text']")
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Image'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link 'Relationships'
      expect(page).to have_content 'Administrative Set'
      find('#dissertation_admin_set_id').text eq 'dissertation admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Dissertation work'

      first('.document-title', text: 'Test Dissertation work').click
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Degree granting institution UNC'

      # extra fields
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Academic concentration Clinical Nutrition'
      expect(page).to have_content 'Advisor advisor ORCID: advisor orcid'
      expect(page).to have_content 'Alternate title another title'
      expect(page).to have_content 'Contributor contributor ORCID: contributor orcid'
      expect(page).to have_content 'Degree Bachelor of Science'
      expect(page).to have_content 'DOI some doi'
      expect(page).to have_content 'Resource type Dissertation'
      expect(page).to have_content 'Access some access'
      expect(page).to have_content 'Location some geographic subject'
      expect(page).to have_content 'Graduation year 2018'
      expect(page).to have_content 'Identifier some id'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Reviewer reviewer ORCID: reviewer orcid'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Use some use'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'
      
      
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: dissertation admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Image'
      expect(page).to have_content "Last Modified #{Date.edtf(DateTime.now.to_s).humanize}"

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
