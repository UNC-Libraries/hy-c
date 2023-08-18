# Generated via
#  `rails generate hyrax:work General`
require 'rails_helper'
include Warden::Test::Helpers
require Rails.root.join('spec/support/hyc_geoname_helper.rb')
require 'active_fedora/cleaner'

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Create a General', js: false do
  include HycGeonameHelper

  context 'a logged in user' do
    let(:user) { FactoryBot.create(:user) }

    let(:admin_user) { FactoryBot.create(:admin) }

    let(:admin_set) do
      AdminSet.create(title: ['general admin set'],
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
      DefaultAdminSet.create(work_type_name: 'General', admin_set_id: admin_set.id)

      stub_geo_request
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_general_path
      expect(page).to have_content 'You are not authorized to access this page'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_general_path
      expect(page).to have_content 'Add New General'

      # required fields
      fill_in 'Title', with: 'Test General work'
      select 'Text', from: 'Dcmi type'

      # extra fields
      fill_in 'Abstract', with: 'an abstract'
      select 'Clinical Nutrition', from: 'Academic Concentration'
      fill_in 'Access Right', with: 'some access'
      fill_in 'Advisor', { with: 'advisor', id: 'general_advisors_attributes_0_name' }
      fill_in 'ORCID', { with: 'advisor orcid', id: 'general_advisors_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_advisors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_advisors_attributes_0_other_affiliation' }
      fill_in 'Alternate title', with: 'another title'
      fill_in 'Arranger', { with: 'arranger', id: 'general_arrangers_attributes_0_name' }
      fill_in 'ORCID', { with: 'arranger orcid', id: 'general_arrangers_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_arrangers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_arrangers_attributes_0_other_affiliation' }
      select 'Honors', from: 'Honors level'
      fill_in 'Bibliographic citation', with: 'a citation'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'general_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'http://orcid.org/creator', id: 'general_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_creators_attributes_0_other_affiliation' }
      fill_in 'Conference name', with: 'a conference'
      fill_in 'Contributor', { with: 'contributor', id: 'general_contributors_attributes_0_name' }
      fill_in 'ORCID', { with: 'contributor orcid', id: 'general_contributors_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_contributors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_contributors_attributes_0_other_affiliation' }
      fill_in 'Copyright date', with: '2018'
      fill_in 'Composer', { with: 'composer', id: 'general_composers_attributes_0_name' }
      fill_in 'ORCID', { with: 'composer orcid', id: 'general_composers_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_composers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_composers_attributes_0_other_affiliation' }
      fill_in 'Date of publication', with: '2018-10-03'
      fill_in 'Date other', with: '2018-10-03'
      select 'Bachelor of Science', from: 'general_degree'
      fill_in 'Degree granting institution', with: 'UNC'
      fill_in 'Description', with: 'a description'
      fill_in 'Digital collection', with: 'my collection'
      fill_in 'DOI', with: 'some-doi'
      select 'Preprint', from: 'general_edition'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Funder', with: 'some funder'
      find('#general_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'Graduation year', with: '2018'
      fill_in 'Identifier', with: 'an identifier'
      fill_in 'ISBN', with: 'some isbn'
      fill_in 'ISSN', with: 'some issn'
      fill_in 'Journal issue', with: '1'
      fill_in 'Journal title', with: 'a journal'
      fill_in 'Journal volume', with: '2'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Text', from: 'general_kind_of_data'
      fill_in 'Last modified date', with: '2018-10-03'
      select 'Attribution 3.0 United States', from: 'general_license'
      fill_in 'Medium', with: 'a medium'
      fill_in 'Methods', with: 'My methodology'
      fill_in 'Note', with: 'a note'
      fill_in 'Page end', with: '32'
      fill_in 'Page start', with: '30'
      fill_in 'Place of publication', with: 'UNC'
      fill_in 'Project Director', { with: 'project director', id: 'general_project_directors_attributes_0_name' }
      fill_in 'ORCID', { with: 'project director orcid', id: 'general_project_directors_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_project_directors_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_project_directors_attributes_0_other_affiliation' }
      select 'Yes', from: 'general_peer_review_status'
      fill_in 'Publisher', with: 'UNC Press'
      select 'Other', from: 'general_resource_type'
      fill_in 'Researcher', { with: 'researcher', id: 'general_researchers_attributes_0_name' }
      fill_in 'ORCID', { with: 'researcher orcid', id: 'general_researchers_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_researchers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_researchers_attributes_0_other_affiliation' }
      fill_in 'Reviewer', { with: 'reviewer', id: 'general_reviewers_attributes_0_name' }
      fill_in 'ORCID', { with: 'reviewer orcid', id: 'general_reviewers_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_reviewers_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_reviewers_attributes_0_other_affiliation' }
      fill_in 'Related resource URL', with: 'something.com'
      fill_in 'Rights holder', with: 'an author'
      select 'In Copyright', from: 'general_rights_statement'
      fill_in 'Series', with: 'a series'
      fill_in 'Sponsor', with: 'a sponsor'
      fill_in 'Subject', with: 'test'
      fill_in 'Table of contents', with: 'contents'
      fill_in 'Translator', { with: 'translator', id: 'general_translators_attributes_0_name' }
      fill_in 'ORCID', { with: 'translator orcid', id: 'general_translators_attributes_0_orcid' }
      select 'Department of Biology', from: 'general_translators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'general_translators_attributes_0_other_affiliation' }
      fill_in 'Rights notes', with: 'some rights notes'

      expect(page).to have_selector('#general_language_label', visible: false)
      expect(page).to have_selector('#general_license_label', visible: false)
      expect(page).to have_selector('#general_rights_statement_label', visible: false)
      expect(page).to have_field('general_visibility_embargo')
      expect(page).not_to have_field('general_visibility_lease')
      expect(page).not_to have_field('general_deposit_agreement')
      expect(page).not_to have_field('general_date_created')
      choose 'general_visibility_open'
      check 'agreement'

      expect(page).to have_selector('#general_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to have_content 'Administrative Set'
      find('#general_admin_set_id').text eq 'general admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test General work'

      first('.document-title', text: 'Test General work').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Academic concentration Clinical Nutrition'
      expect(page).to have_content 'Access right some access'
      expect(page).to have_content 'Advisor advisor ORCID: advisor orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Alternate title another title'
      expect(page).to have_content 'Arranger arranger ORCID: arranger orcid'
      expect(page).to have_content 'Honors level Honors'
      expect(page).to have_content 'Bibliographic citation a citation'
      expect(page).to have_content 'Composer composer ORCID: composer orcid'
      expect(page).to have_content 'Conference name a conference'
      expect(page).to have_content 'Contributor contributor ORCID: contributor orcid'
      expect(page).to have_content 'Copyright date 2018'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Date other October 3, 2018'
      expect(page).to have_content 'Degree Bachelor of Science'
      expect(page).to have_content 'Degree granting institution UNC'
      expect(page).to have_content 'a description'
      expect(page).to have_content 'Digital collection my collection'
      expect(page).to have_content 'DOI some-doi'
      expect(page).to have_content 'Version Preprint'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'Graduation year 2018'
      expect(page).to have_content 'Identifier an identifier'
      expect(page).to have_content 'ISBN some isbn'
      expect(page).to have_content 'ISSN some issn'
      expect(page).to have_content 'Journal issue 1'
      expect(page).to have_content 'Journal title a journal'
      expect(page).to have_content 'Journal volume 2'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Kind of data Text'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Last modified date October 3, 2018'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Methodology My methodology'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Page end 32'
      expect(page).to have_content 'Page start 30'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Project director project director ORCID: project director orcid'
      expect(page).to have_content 'Is the article or chapter peer-reviewed? Yes'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Resource type Other'
      expect(page).to have_content 'Researcher researcher ORCID: researcher orcid'
      expect(page).to have_content 'Reviewer reviewer ORCID: reviewer orcid'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Series a series'
      expect(page).to have_content 'Sponsor a sponsor'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Table of contents contents'
      expect(page).to have_content 'Translator translator ORCID: translator orcid'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_content 'In Administrative Set: general admin set'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
