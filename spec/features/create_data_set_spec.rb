# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Create a DataSet', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ['data set admin set'],
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
      DefaultAdminSet.create(work_type_name: 'DataSet', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_data_set_path
      expect(page).to have_content 'Add New Dataset'

      # required fields
      fill_in 'Title', with: 'Test Data Set'
      fill_in 'Name', { with: 'Test Default Creator', id: 'data_set_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'data_set_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_creators_attributes_0_other_affiliation' }
      select 'Text', from: 'data_set_kind_of_data'
      select 'Dataset', from: 'data_set_resource_type'
      fill_in 'Abstract', with: 'some abstract'
      fill_in 'Date of publication', with: '2018-10-03'

      # extra fields
      fill_in 'Name', { with: 'contributor', id: 'data_set_contributors_attributes_0_name' }
      fill_in 'ORCID', { with: 'contributor orcid', id: 'data_set_contributors_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_contributors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_contributors_attributes_0_other_affiliation' }
      fill_in 'Description', with: 'a description'
      fill_in 'Funder', with: 'some funder'
      fill_in 'Location', with: 'some geographic subject'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'data_set_language'
      fill_in 'Last modified date', with: '2018-10-03'
      select 'Attribution 3.0 United States', :from => 'data_set_license'
      fill_in 'Name', { with: 'project director', id: 'data_set_project_directors_attributes_0_name' }
      fill_in 'ORCID', { with: 'project director orcid', id: 'data_set_project_directors_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_project_directors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_project_directors_attributes_0_other_affiliation' }
      fill_in 'Name', { with: 'researcher', id: 'data_set_researchers_attributes_0_name' }
      fill_in 'ORCID', { with: 'researcher orcid', id: 'data_set_researchers_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_researchers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_researchers_attributes_0_other_affiliation' }
      fill_in 'Rights holder', with: 'an author'
      fill_in 'Related resource URL', with: 'something.com'
      select 'In Copyright', :from => 'data_set_rights_statement'
      fill_in 'Sponsor', with: 'a sponsor'
      fill_in 'Subject', with: 'test'

      expect(page).not_to have_field('data_set_date_access')
      expect(page).not_to have_field('data_set_date_created')
      expect(page).not_to have_field('data_set_doi')
      expect(page).not_to have_field('data_set_extent')
      expect(page).to have_selector('#data_set_language_label', visible: false)
      expect(page).to have_selector('#data_set_license_label', visible: false)
      expect(page).to have_selector('#data_set_rights_statement_label', visible: false)
      expect(page).to have_field('data_set_rights_statement')
      expect(page).to have_field('data_set_visibility_embargo')
      expect(page).not_to have_field('data_set_visibility_lease')
      expect(page).to have_select('data_set_resource_type', selected: 'Dataset')
      choose 'data_set_visibility_open'
      check 'agreement'
      
      expect(page).not_to have_selector('#data_set_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link 'Relationships'
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Data Set'

      first('.document-title', text: 'Test Data Set').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Kind of data Text'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Resource type Dataset'
      expect(page).to have_content 'Contributor contributor ORCID: contributor orcid'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Location some geographic subject'
      expect(page).to have_content 'Last modified date October 3, 2018'
      expect(page).to have_content 'Project director project director ORCID: project director orcid'
      expect(page).to have_content 'Researcher researcher ORCID: researcher orcid'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Sponsor a sponsor'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: data set admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Dataset'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_data_set_path
      expect(page).to have_content 'Add New Dataset'

      # required fields
      fill_in 'Title', with: 'Test Data Set'
      fill_in 'Name', { with: 'Test Default Creator', id: 'data_set_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'data_set_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_creators_attributes_0_other_affiliation' }
      select 'Text', from: 'data_set_kind_of_data'
      select 'Dataset', from: 'data_set_resource_type'
      fill_in 'Abstract', with: 'some abstract'
      fill_in 'Date of publication', with: '2018-10-03'

      # extra fields
      fill_in 'Name', { with: 'contributor', id: 'data_set_contributors_attributes_0_name' }
      fill_in 'ORCID', { with: 'contributor orcid', id: 'data_set_contributors_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_contributors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_contributors_attributes_0_other_affiliation' }
      fill_in 'Description', with: 'a description'
      fill_in 'DOI', with: 'some doi'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Funder', with: 'some funder'
      fill_in 'Location', with: 'some geographic subject'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'English', from: 'data_set_language'
      fill_in 'Last modified date', with: '2018-10-03'
      select 'Attribution 3.0 United States', :from => 'data_set_license'
      fill_in 'Name', { with: 'project director', id: 'data_set_project_directors_attributes_0_name' }
      fill_in 'ORCID', { with: 'project director orcid', id: 'data_set_project_directors_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_project_directors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_project_directors_attributes_0_other_affiliation' }
      fill_in 'Name', { with: 'researcher', id: 'data_set_researchers_attributes_0_name' }
      fill_in 'ORCID', { with: 'researcher orcid', id: 'data_set_researchers_attributes_0_orcid' }
      select 'Department of Biology', from: 'data_set_researchers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'data_set_researchers_attributes_0_other_affiliation' }
      fill_in 'Rights holder', with: 'an author'
      fill_in 'Related resource URL', with: 'something.com'
      select 'In Copyright', :from => 'data_set_rights_statement'
      fill_in 'Sponsor', with: 'a sponsor'
      fill_in 'Subject', with: 'test'

      expect(page).to have_selector('#data_set_language_label', visible: false)
      expect(page).to have_selector('#data_set_license_label', visible: false)
      expect(page).to have_selector('#data_set_rights_statement_label', visible: false)
      expect(page).to have_field('data_set_rights_statement')
      expect(page).to have_field('data_set_visibility_embargo')
      expect(page).not_to have_field('data_set_visibility_lease')
      expect(page).to have_select('data_set_resource_type', selected: 'Dataset')
      choose 'data_set_visibility_open'
      check 'agreement'
      
      expect(page).to have_selector('#data_set_dcmi_type')
      expect(page).to have_selector("input[value='http://purl.org/dc/dcmitype/Dataset']")
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Image'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link 'Relationships'
      expect(page).to have_content 'Administrative Set'
      find('#data_set_admin_set_id').text eq 'data set admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Data Set'

      first('.document-title', text: 'Test Data Set').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Kind of data Text'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Resource type Dataset'
      expect(page).to have_content 'Contributor contributor ORCID: contributor orcid'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'DOI some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Location some geographic subject'
      expect(page).to have_content 'Last modified date October 3, 2018'
      expect(page).to have_content 'Project director project director ORCID: project director orcid'
      expect(page).to have_content 'Researcher researcher ORCID: researcher orcid'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Sponsor a sponsor'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: data set admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Image'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
