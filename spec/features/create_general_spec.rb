# Generated via
#  `rails generate hyrax:work General`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Create a General', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

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
      DefaultAdminSet.create(work_type_name: 'General', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_general_path
      expect(page).to have_content "You are not authorized to access this page"
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_general_path
      expect(page).to have_content 'Add New General'

      # required fields
      fill_in 'Title', with: 'Test General work'

      # extra fields
      fill_in 'Abstract', with: 'an abstract'
      select 'Clinical Nutrition', from: 'Academic Concentration'
      fill_in 'Access', with: 'some access'
      fill_in 'Advisor', with: 'an advisor'
      select 'Department of Biology', from: 'general_affiliation'
      fill_in 'Alternative title', with: 'another title'
      fill_in 'Arranger', with: 'an arranger'
      fill_in 'Award', with: 'an award'
      fill_in 'Bibliographic citation', with: 'a citation'
      fill_in 'Composer', with: 'a conference'
      fill_in 'Conference name', with: 'a composer'
      fill_in 'Contributor', with: 'a contributor'
      fill_in 'Copyright date', with: '2018-10-03'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Date Created', with: '2018-10-03'
      fill_in 'Date issued', with: '2018-10-03'
      fill_in 'Date other', with: '2018-10-03'
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Text'
      select 'Bachelor of Science', from: 'general_degree'
      fill_in 'Degree granting institution', with: 'UNC'
      fill_in 'Description', with: 'a description'
      fill_in 'Deposit record', with: 'a deposit record'
      fill_in 'Doi', with: 'some doi'
      select 'Preprint', from: 'general_edition'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Funder', with: 'some funder'
      fill_in 'Geographic subject', with: 'some geographic subject'
      fill_in 'Graduation year', with: '2018'
      fill_in 'Identifier', with: 'an identifier'
      fill_in 'Isbn', with: 'some isbn'
      fill_in 'Issn', with: 'some issn'
      fill_in 'Journal issue', with: '1'
      fill_in 'Journal title', with: 'a journal'
      fill_in 'Journal volume', with: '2'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Text', from: 'general_kind_of_data'
      select 'English', from: 'general_language'
      fill_in 'Last modified date', with: '2018-10-03'
      select 'Attribution 3.0 United States', :from => 'general_license'
      fill_in 'Medium', with: 'a medium'
      fill_in 'Note', with: 'a note'
      fill_in 'Orcid', with: 'an orcid'
      fill_in 'Other affiliation', with: 'another affiliation'
      fill_in 'Page end', with: '32'
      fill_in 'Page start', with: '30'
      fill_in 'Place of publication', with: 'UNC'
      fill_in 'Project director', with: 'a director'
      select 'Yes', from: 'general_peer_review_status'
      fill_in 'Publisher', with: 'UNC Press'
      fill_in 'Publisher version', with: 'a version'
      select 'Other', from: 'general_resource_type'
      fill_in 'Researcher', with: 'a researcher'
      fill_in 'Reviewer', with: 'a reviewer'
      fill_in 'Related URL', with: 'something.com'
      fill_in 'Rights holder', with: 'an author'
      select 'In Copyright', :from => 'general_rights_statement'
      fill_in 'Series', with: 'a series'
      fill_in 'Sponsor', with: 'a sponsor'
      fill_in 'Subject', with: 'test'
      fill_in 'Table of contents', with: 'contents'
      fill_in 'Translator', with: 'none'
      fill_in 'Use', with: 'some use'
      fill_in 'Url', with: 'some url'

      expect(page).to have_field('general_language_label')
      expect(page).to have_field('general_license_label')
      expect(page).to have_field('general_rights_statement_label')
      expect(page).to have_field('general_visibility_embargo')
      expect(page).not_to have_field('general_visibility_lease')
      choose 'general_visibility_open'
      check 'agreement'
      
      expect(page).to have_selector('#general_dcmi_type')

      within '//span[@id=addfiles]' do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link 'Relationships'
      expect(page).to have_content 'Administrative Set'
      find('#general_admin_set_id').text eq 'general admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test General work'

      first('.document-title', text: 'Test General work').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Academic concentration Clinical Nutrition'
      expect(page).to have_content 'Access some access'
      expect(page).to have_content 'Advisor an advisor'
      expect(page).to have_content 'Affiliation'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Alternative title another title'
      expect(page).to have_content 'Arranger an arranger'
      expect(page).to have_content 'Award an award'
      expect(page).to have_content 'Bibliographic citation a citation'
      expect(page).to have_content 'Composer a conference'
      expect(page).to have_content 'Conference name a composer'
      expect(page).to have_content 'Contributors a contributor'
      expect(page).to have_content 'Copyright date October 3, 2018'
      expect(page).to have_content 'Creator Test Default Creator'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Date issued October 3, 2018'
      expect(page).to have_content 'Date other October 3, 2018'
      expect(page).to have_content 'Degree Bachelor of Science'
      expect(page).to have_content 'Degree granting institution UNC'
      expect(page).to have_content 'Description a description'
      expect(page).to have_content 'Deposit record a deposit record'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Edition Preprint'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Geographic subject some geographic subject'
      expect(page).to have_content 'Graduation year 2018'
      expect(page).to have_content 'Identifier an identifier'
      expect(page).to have_content 'Isbn some isbn'
      expect(page).to have_content 'Issn some issn'
      expect(page).to have_content 'Journal issue 1'
      expect(page).to have_content 'Journal title a journal'
      expect(page).to have_content 'Journal volume 2'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Kind of data Text'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Last modified date October 3, 2018'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Orcid an orcid'
      expect(page).to have_content 'Other affiliation another affiliation'
      expect(page).to have_content 'Page end 32'
      expect(page).to have_content 'Page start 30'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Project director a director'
      expect(page).to have_content 'Peer review status Yes'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Publisher version a version'
      expect(page).to have_content 'Resource type Other'
      expect(page).to have_content 'Researcher a researcher'
      expect(page).to have_content 'Reviewer a reviewer'
      expect(page).to have_content 'Related url something.com'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Series a series'
      expect(page).to have_content 'Sponsor a sponsor'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Table of contents contents'
      expect(page).to have_content 'Translator none'
      expect(page).to have_content 'Use some use'
      expect(page).to have_content 'Url some url'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_content 'In Administrative Set: general admin set'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
