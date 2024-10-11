# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'
include Warden::Test::Helpers
require Rails.root.join('spec/support/hyc_geoname_helper.rb')

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a Journal', js: false do
  include HycGeonameHelper

  context 'a logged in user' do
    let(:user) { FactoryBot.create(:user) }

    let(:admin_user) { FactoryBot.create(:admin) }

    let(:admin_set) do
      AdminSet.create(title: ['journal admin set'],
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
      DefaultAdminSet.create(work_type_name: 'Journal', admin_set_id: admin_set.id)

      stub_geo_request
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_journal_path
      expect(page).to have_content 'Add New Scholarly Journal, Newsletter or Book'

      # required fields
      fill_in 'Title', with: 'Test Journal work'
      fill_in 'Date of publication', with: '2018-10-03'
      fill_in 'Publisher', with: 'UNC Press'

      # extra fields
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Creator', with: 'Test Default Creator', id: 'journal_creators_attributes_0_name'
      fill_in 'ORCID', with: 'http://orcid.org/creator', id: 'journal_creators_attributes_0_orcid'
      select 'Department of Biology', from: 'journal_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', with: 'UNC', id: 'journal_creators_attributes_0_other_affiliation'
      fill_in 'Extent', with: 'some extent'
      find('#journal_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'ISBN', with: 'some isbn'
      fill_in 'ISSN', with: 'some issn'
      select 'Preprint', from: 'Version'
      fill_in 'Related resource URL', with: 'a url'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 4.0 International', from: 'journal_license'
      fill_in 'Note', with: 'a note'
      fill_in 'Place of publication', with: 'UNC'
      select 'Journal', from: 'journal_resource_type'
      select 'In Copyright', from: 'journal_rights_statement'
      fill_in 'Series', with: 'series1'
      fill_in 'Subject', with: 'test'

      expect(page).to have_selector('#journal_language_label', visible: false)
      expect(page).to have_selector('#journal_license_label', visible: false)
      expect(page).to have_selector('#journal_rights_statement_label', visible: false)
      expect(page).not_to have_field('journal_alternative_title')
      expect(page).not_to have_field('journal_digital_collection')
      expect(page).not_to have_field('journal_doi')
      expect(page).to have_field('journal_visibility_embargo')
      expect(page).not_to have_field('journal_visibility_lease')
      expect(page).not_to have_field('journal_deposit_agreement')
      choose 'journal_visibility_open'
      check 'agreement'

      expect(page).not_to have_selector('#journal_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Journal'

      first('.document-title', text: 'Test Journal').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'ISBN some isbn'
      expect(page).to have_content 'ISSN some issn'
      expect(page).to have_content 'Version Preprint'
      expect(page).to have_content 'Related resource URL a url'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 4.0 International'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Resource type Journal'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Series series1'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/4.0/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: journal admin set'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_journal_path
      expect(page).to have_content 'Add New Scholarly Journal, Newsletter or Book'

      # required fields
      fill_in 'Title', with: 'Test Journal work'
      fill_in 'Date of publication', with: '2018-10-03'
      fill_in 'Publisher', with: 'UNC Press'

      # extra fields
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Alternate title', with: 'another title'
      fill_in 'Creator', with: 'Test Default Creator', id: 'journal_creators_attributes_0_name'
      fill_in 'ORCID', with: 'http://orcid.org/creator', id: 'journal_creators_attributes_0_orcid'
      select 'Department of Biology', from: 'journal_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', with: 'UNC', id: 'journal_creators_attributes_0_other_affiliation'
      fill_in 'Digital collection', with: 'my collection'
      fill_in 'DOI', with: 'some-doi'
      fill_in 'Extent', with: 'some extent'
      find('#journal_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'ISBN', with: 'some isbn'
      fill_in 'ISSN', with: 'some issn'
      select 'Preprint', from: 'Version'
      fill_in 'Related resource URL', with: 'a url'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 3.0 United States', from: 'journal_license'
      fill_in 'Note', with: 'a note'
      fill_in 'Place of publication', with: 'UNC'
      select 'Journal', from: 'journal_resource_type'
      select 'In Copyright', from: 'journal_rights_statement'
      fill_in 'Series', with: 'series1'
      fill_in 'Subject', with: 'test'

      expect(page).to have_selector('#journal_language_label', visible: false)
      expect(page).to have_selector('#journal_license_label', visible: false)
      expect(page).to have_selector('#journal_rights_statement_label', visible: false)
      expect(page).to have_field('journal_visibility_embargo')
      expect(page).not_to have_field('journal_visibility_lease')
      expect(page).not_to have_field('journal_deposit_agreement')
      expect(page).not_to have_field('journal_date_created')
      choose 'journal_visibility_open'
      check 'agreement'

      expect(page).to have_selector('#journal_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to have_content 'Administrative Set'
      find('#journal_admin_set_id').text eq 'journal admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Journal'

      first('.document-title', text: 'Test Journal').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Alternate title another title'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Digital collection my collection'
      expect(page).to have_content 'DOI some-doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'ISBN some isbn'
      expect(page).to have_content 'ISSN some issn'
      expect(page).to have_content 'Version Preprint'
      expect(page).to have_content 'Related resource URL a url'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Resource type Journal'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Series series1'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: journal admin set'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
