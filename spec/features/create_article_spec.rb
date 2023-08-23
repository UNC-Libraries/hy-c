# Generated via
#  `rails generate hyrax:work Article`
require 'rails_helper'
include Warden::Test::Helpers
require Rails.root.join('spec/support/hyc_geoname_helper.rb')

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Create a Article', js: false do
  include HycGeonameHelper

  context 'a logged in user' do
    let(:user) { FactoryBot.create(:user) }

    let(:admin_user) { FactoryBot.create(:admin) }

    let(:admin_set) do
      AdminSet.create(title: ['article admin set'],
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
      DefaultAdminSet.create(work_type_name: 'Article', admin_set_id: admin_set.id)

      stub_geo_request
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_article_path
      expect(page).to have_content 'Add New Scholarly Article or Book Chapter'

      # required fields
      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'article_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'http://orcid.org/creator', id: 'article_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'article_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'article_creators_attributes_0_other_affiliation' }
      fill_in 'Abstract', with: 'some abstract'
      fill_in 'Date of publication', with: '2018-10-03'

      # extra fields
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 3.0 United States', from: 'article_license'
      select 'In Copyright', from: 'article_rights_statement'
      fill_in 'Publisher', with: 'UNC Press'
      fill_in 'Subject', with: 'test'
      fill_in 'Related resource URL', with: 'something.com'
      fill_in 'Alternate title', with: 'my other title'
      select 'Article', from: 'article_resource_type'
      select 'Preprint', from: 'article_edition'
      fill_in 'Funder', with: 'some funder'
      find('#article_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'ISSN', with: 'some issn'
      fill_in 'Journal issue', with: '1'
      fill_in 'Journal title', with: 'a journal'
      fill_in 'Journal volume', with: '2'
      fill_in 'Note', with: 'a note'
      fill_in 'Page end', with: '32'
      fill_in 'Page start', with: '30'
      select 'Yes', from: 'article_peer_review_status'
      fill_in 'Place of publication', with: 'UNC'

      expect(page).to have_selector('#article_language_label', visible: false)
      expect(page).to have_selector('#article_license_label', visible: false)
      expect(page).to have_selector('#article_rights_statement_label', visible: false)
      expect(page).not_to have_field('article_access')
      expect(page).not_to have_field('article_bibliographic_citation')
      expect(page).not_to have_field('article_copyright_date')
      expect(page).not_to have_field('article_date_created')
      expect(page).not_to have_field('article_date_other')
      expect(page).not_to have_field('article_digital_collection')
      expect(page).not_to have_field('article_doi')
      expect(page).not_to have_field('article_extent')
      expect(page).not_to have_field('article_rights_holder')
      expect(page).not_to have_field('article_translator')
      expect(page).to have_field('article_visibility_embargo')
      expect(page).not_to have_field('article_visibility_lease')
      expect(page).not_to have_field('article_identifier')
      expect(page).not_to have_field('article_use')
      expect(page).not_to have_field('article_deposit_agreement')
      expect(page).to have_select('article_resource_type', selected: 'Article')
      choose 'article_visibility_open'
      check 'agreement'

      expect(page).not_to have_selector('#article_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Alternate title my other title'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Resource type Article'
      expect(page).to have_content 'Version Preprint'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'ISSN some issn'
      expect(page).to have_content 'Journal issue 1'
      expect(page).to have_content 'Journal title a journal'
      expect(page).to have_content 'Journal volume 2'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Page end 32'
      expect(page).to have_content 'Page start 30'
      expect(page).to have_content 'Is the article or chapter peer-reviewed? Yes'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: article admin set'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to_not have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_article_path
      expect(page).to have_content 'Add New Scholarly Article or Book Chapter'

      # required fields
      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'article_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'http://orcid.org/creator', id: 'article_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'article_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'article_creators_attributes_0_other_affiliation' }
      fill_in 'Abstract', with: 'some abstract'
      fill_in 'Date of publication', with: '2018-10-03'

      # extra fields
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 3.0 United States', from: 'article_license'
      select 'In Copyright', from: 'article_rights_statement'
      fill_in 'Publisher', with: 'UNC Press'
      fill_in 'Subject', with: 'test'
      fill_in 'Identifier', with: 'some id'
      fill_in 'Related resource URL', with: 'something.com'
      select 'Article', from: 'article_resource_type'
      fill_in 'Access Right', with: 'some access'
      fill_in 'Alternate title', with: 'my other title'
      fill_in 'Bibliographic citation', with: 'a citation'
      fill_in 'Copyright date', with: '2018'
      fill_in 'Date other', with: '2018-10-03'
      fill_in 'Digital collection', with: 'my collection'
      fill_in 'DOI', with: 'some-doi'
      select 'Preprint', from: 'article_edition'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Funder', with: 'some funder'
      find('#article_based_near_attributes_0_id', visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'ISSN', with: 'some issn'
      fill_in 'Journal issue', with: '1'
      fill_in 'Journal title', with: 'a journal'
      fill_in 'Journal volume', with: '2'
      fill_in 'Note', with: 'a note'
      fill_in 'Page end', with: '32'
      fill_in 'Page start', with: '30'
      select 'Yes', from: 'article_peer_review_status'
      fill_in 'Place of publication', with: 'UNC'
      fill_in 'Rights holder', with: 'an author'
      fill_in 'Translator', { with: 'translator', id: 'article_translators_attributes_0_name' }
      fill_in 'ORCID', { with: 'translator orcid', id: 'article_translators_attributes_0_orcid' }
      select 'Department of Biology', from: 'article_translators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'article_translators_attributes_0_other_affiliation' }
      fill_in 'Rights notes', with: 'some rights notes'

      expect(page).to have_selector('#article_language_label', visible: false)
      expect(page).to have_selector('#article_license_label', visible: false)
      expect(page).to have_selector('#article_rights_statement_label', visible: false)
      expect(page).to have_field('article_visibility_embargo')
      expect(page).not_to have_field('article_visibility_lease')
      expect(page).not_to have_field('article_deposit_agreement')
      expect(page).not_to have_field('article_date_created')
      expect(page).to have_select('article_resource_type', selected: 'Article')
      choose 'article_visibility_open'
      check 'agreement'

      expect(page).to have_selector('#article_dcmi_type')

      within('div#add-files') do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), visible: false)
      end

      click_link 'Add to Collection'
      expect(page).to have_content 'Administrative Set'
      find('#article_admin_set_id').text eq 'article admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator ORCID: http://orcid.org/creator'
      expect(page.find_link('http://orcid.org/creator')[:target]).to eq('_blank')
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Identifier some id'
      expect(page).to have_content 'Related resource URL something.com'
      expect(page).to have_content 'Resource type Article'
      expect(page).to have_content 'Access right some access'
      expect(page).to have_content 'Alternate title my other title'
      expect(page).to have_content 'Bibliographic citation a citation'
      expect(page).to have_content 'Copyright date 2018'
      expect(page).to have_content 'Date other October 3, 2018'
      expect(page).to have_content 'Digital collection my collection'
      expect(page).to have_content 'DOI some-doi'
      expect(page).to have_content 'Version Preprint'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Location Chapel Hill, North Carolina, United States'
      expect(page).to have_content 'ISSN some issn'
      expect(page).to have_content 'Journal issue 1'
      expect(page).to have_content 'Journal title a journal'
      expect(page).to have_content 'Journal volume 2'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Page end 32'
      expect(page).to have_content 'Page start 30'
      expect(page).to have_content 'Is the article or chapter peer-reviewed? Yes'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Translator translator ORCID: translator orcid'
      expect(page).to have_content 'Rights notes some rights notes'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: article admin set'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
