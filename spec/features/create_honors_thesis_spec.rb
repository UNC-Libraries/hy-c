# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'
include Warden::Test::Helpers
require Rails.root.join('spec/support/hyc_geoname_helper.rb')

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a HonorsThesis', js: false do
  include HycGeonameHelper

  context 'a logged in user' do
    let(:user) { FactoryBot.create(:user) }

    let(:admin_user) { FactoryBot.create(:admin) }

    let(:admin_set) do
      AdminSet.create(title: ['honors thesis admin set'],
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
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit

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
      Hyrax::Workflow::PermissionGenerator.call(roles: 'deleting', workflow: workflow, agents: admin_agent)
      permission_template.available_workflows.first.update!(active: true)
      DefaultAdminSet.create(work_type_name: 'HonorsThesis', admin_set_id: admin_set.id)

      stub_geo_request
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_honors_thesis_path
      expect(page).to have_content 'Add New Undergraduate Honors Thesis'

      # required fields
      fill_in 'Title', with: 'Test HonorsThesis work'
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Advisor', with: 'advisor', id: 'honors_thesis_advisors_attributes_0_name'
      fill_in 'ORCID', with: 'advisor orcid', id: 'honors_thesis_advisors_attributes_0_orcid'
      select 'Department of Biology', from: 'honors_thesis_advisors_attributes_0_affiliation'
      fill_in 'Additional affiliation', with: 'UNC', id: 'honors_thesis_advisors_attributes_0_other_affiliation'
      fill_in 'Creator', with: 'Test Default Creator', id: 'honors_thesis_creators_attributes_0_name'
      fill_in 'ORCID', with: 'http://orcid.org/creator', id: 'honors_thesis_creators_attributes_0_orcid'
      select 'Department of Biology', from: 'honors_thesis_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', with: 'UNC', id: 'honors_thesis_creators_attributes_0_other_affiliation'
      fill_in 'Date of publication', with: '2018-10-03'
      select 'Bachelor of Science', from: 'honors_thesis_degree'
      fill_in 'Graduation year', with: '2018'

      # extra fields
      find('#honors_thesis_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 4.0 International', from: 'honors_thesis_license'
      fill_in 'Note', with: 'a note'
      select 'Honors Thesis', from: 'honors_thesis_resource_type'
      fill_in 'Related resource URL', with: 'something.com'
      select 'In Copyright', from: 'honors_thesis_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).not_to have_field('honors_thesis_access')
      expect(page).not_to have_field('honors_thesis_date_created')
      expect(page).not_to have_field('honors_thesis_degree_granting_institution')
      expect(page).not_to have_field('honors_thesis_doi')
      expect(page).to have_selector('#honors_thesis_language_label', visible: false)
      expect(page).to have_selector('#honors_thesis_license_label', visible: false)
      expect(page).to have_selector('#honors_thesis_rights_statement_label', visible: false)
      expect(page).not_to have_field('honors_thesis_academic_concentration')
      expect(page).not_to have_field('honors_thesis_award')
      expect(page).not_to have_field('honors_thesis_extent')
      expect(page).not_to have_field('honors_thesis_use')
      expect(page).to have_field('honors_thesis_visibility_embargo')
      expect(page).not_to have_field('honors_thesis_visibility_lease')
      expect(page).not_to have_field('honors_thesis_deposit_agreement')
      expect(page).to have_select('honors_thesis_resource_type', selected: 'Honors Thesis')
      choose 'honors_thesis_visibility_open'
      check 'agreement'

      expect(page).not_to have_selector('#honors_thesis_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test HonorsThesis work'

      first('.document-title', text: 'Test HonorsThesis work').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Advisor advisor ORCID: advisor orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Degree Bachelor of Science'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'Graduation year 2018'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 4.0 International'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Resource type Honors Thesis'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/4.0/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: honors thesis admin set'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_honors_thesis_path
      expect(page).to have_content 'Add New Undergraduate Honors Thesis'

      # required fields
      fill_in 'Title', with: 'Test HonorsThesis work'
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Advisor', with: 'advisor', id: 'honors_thesis_advisors_attributes_0_name'
      fill_in 'ORCID', with: 'advisor orcid', id: 'honors_thesis_advisors_attributes_0_orcid'
      select 'Department of Biology', from: 'honors_thesis_advisors_attributes_0_affiliation'
      fill_in 'Additional affiliation', with: 'UNC', id: 'honors_thesis_advisors_attributes_0_other_affiliation'
      fill_in 'Creator', with: 'Test Default Creator', id: 'honors_thesis_creators_attributes_0_name'
      fill_in 'ORCID', with: 'http://orcid.org/creator', id: 'honors_thesis_creators_attributes_0_orcid'
      select 'Department of Biology', from: 'honors_thesis_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', with: 'UNC', id: 'honors_thesis_creators_attributes_0_other_affiliation'
      fill_in 'Date of publication', with: '2018-10-03'
      select 'Honors', from: 'Honors level'
      select 'Bachelor of Science', from: 'honors_thesis_degree'
      fill_in 'Degree granting institution', with: 'UNC'
      fill_in 'Graduation year', with: '2018'

      # extra fields
      select 'Biostatistics', from: 'Academic Concentration'
      fill_in 'Access Right', with: 'some access'
      fill_in 'DOI', with: 'some-doi'
      fill_in 'Extent', with: 'some extent'
      find('#honors_thesis_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 3.0 United States', from: 'honors_thesis_license'
      fill_in 'Note', with: 'a note'
      select 'Honors Thesis', from: 'honors_thesis_resource_type'
      fill_in 'Related resource URL', with: 'something.com'
      select 'In Copyright', from: 'honors_thesis_rights_statement'
      fill_in 'Subject', with: 'test'
      fill_in 'Rights notes', with: 'some rights notes'

      expect(page).to have_selector('#honors_thesis_language_label', visible: false)
      expect(page).to have_selector('#honors_thesis_license_label', visible: false)
      expect(page).to have_selector('#honors_thesis_rights_statement_label', visible: false)
      expect(page).to have_field('honors_thesis_visibility_embargo')
      expect(page).not_to have_field('honors_thesis_visibility_lease')
      expect(page).not_to have_field('honors_thesis_deposit_agreement')
      expect(page).not_to have_field('honors_thesis_date_created')
      expect(page).to have_select('honors_thesis_resource_type', selected: 'Honors Thesis')
      choose 'honors_thesis_visibility_open'
      check 'agreement'

      expect(page).to have_selector('#honors_thesis_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to have_content 'Administrative Set'
      find('#honors_thesis_admin_set_id').text eq 'honors thesis admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test HonorsThesis work'

      first('.document-title', text: 'Test HonorsThesis work').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Access right some access'
      expect(page).to have_content 'Advisor advisor ORCID: advisor orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'DOI some-doi'
      expect(page).to have_content 'Honors level Honors'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Degree Bachelor of Science'
      expect(page).to have_content 'Degree granting institution UNC'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'Graduation year 2018'
      expect(page).to have_content 'Academic concentration Biostatistics'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Resource type Honors Thesis'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: honors thesis admin set'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
