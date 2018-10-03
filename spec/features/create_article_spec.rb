# Generated via
#  `rails generate hyrax:work Article`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a Article', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["article admin set"],
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
      DefaultAdminSet.create(work_type_name: 'Article', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_article_path
      expect(page).to have_content "Add New Scholarly Article or Book Chapter"

      # required fields
      fill_in 'Title', with: 'Test Article work'
      fill_in 'Author', with: 'Test Default Creator'
      fill_in 'Abstract', with: 'some abstract'
      fill_in 'Date of Publication', with: '2018-10-03'

      # extra fields
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "Attribution 3.0 United States", :from => "article_license"
      select "In Copyright", :from => "article_rights_statement"
      fill_in 'Publisher', with: 'UNC Press'
      fill_in 'Date Created', with: '2018-10-03'
      fill_in 'Subject', with: 'test'
      select 'English', from: 'article_language'
      fill_in 'Identifier', with: 'some id'
      fill_in 'Related Resource URL', with: 'somthing.com'
      select 'Article', from: 'article_resource_type'
      fill_in 'Access', with: 'some access'
      select 'Department of Biology', from: 'article_affiliation'
      fill_in 'Bibliographic citation', with: 'a citation'
      fill_in 'Copyright date', with: '2018-10-03'
      fill_in 'Date captured', with: '2018-10-03'
      fill_in 'Date other', with: '2018-10-03'
      fill_in 'Publisher-issued DOI', with: 'some doi'
      select 'Preprint', from: 'article_edition'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Funder', with: 'some funder'
      fill_in 'Geographic subject', with: 'some geographic subject'
      fill_in 'Issn', with: 'some issn'
      fill_in 'Journal issue', with: '1'
      fill_in 'Journal title', with: 'a journal'
      fill_in 'Journal volume', with: '2'
      fill_in 'Note', with: 'a note'
      fill_in 'Orcid', with: 'an orcid'
      fill_in 'Other affiliation', with: 'another affiliation'
      fill_in 'Page end', with: '32'
      fill_in 'Page start', with: '30'
      select 'Yes', from: 'article_peer_review_status'
      fill_in 'Place of publication', with: 'UNC'
      fill_in 'Rights holder', with: 'an author'
      fill_in 'Table of contents', with: 'contents'
      fill_in 'Translator', with: 'none'
      fill_in 'Link to Publisher Version', with: 'something.org'
      fill_in 'Use', with: 'some use'


      expect(page).to have_field('article_visibility_embargo')
      expect(page).not_to have_field('article_visibility_lease')
      expect(page).to have_select('article_resource_type', selected: 'Article')
      choose "article_visibility_open"
      check 'agreement'
      
      expect(page).not_to have_selector('#article_dcmi_type')

      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator'
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Date issued October 3, 2018'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Identifier some id'
      expect(page).to have_content 'Related url somthing.com'
      expect(page).to have_content 'Resource type Article'
      expect(page).to have_content 'Access some access'
      expect(page).to have_content 'Affiliation'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Bibliographic citation a citation'
      expect(page).to have_content 'Copyright date October 3, 2018'
      expect(page).to have_content 'Date captured October 3, 2018'
      expect(page).to have_content 'Date other October 3, 2018'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Edition Preprint'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Geographic subject some geographic subject'
      expect(page).to have_content 'Issn some issn'
      expect(page).to have_content 'Journal issue 1'
      expect(page).to have_content 'Journal title a journal'
      expect(page).to have_content 'Journal volume 2'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Orcid an orcid'
      expect(page).to have_content 'Other affiliation another affiliation'
      expect(page).to have_content 'Page end 32'
      expect(page).to have_content 'Page start 30'
      expect(page).to have_content 'Peer review status Yes'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Table of contents contents'
      expect(page).to have_content 'Translator none'
      expect(page).to have_content 'Url something.org'
      expect(page).to have_content 'Use some use'

      expect(page).to_not have_content 'In Administrative Set: article admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to_not have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_article_path
      expect(page).to have_content "Add New Scholarly Article or Book Chapter"

      # required fields
      fill_in 'Title', with: 'Test Article work'
      fill_in 'Author', with: 'Test Default Creator'
      fill_in 'Abstract', with: 'some abstract'
      fill_in 'Date of Publication', with: '2018-10-03'

      # extra fields
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "Attribution 3.0 United States", :from => "article_license"
      select "In Copyright", :from => "article_rights_statement"
      fill_in 'Publisher', with: 'UNC Press'
      fill_in 'Date Created', with: '2018-10-03'
      fill_in 'Subject', with: 'test'
      select 'English', from: 'article_language'
      fill_in 'Identifier', with: 'some id'
      fill_in 'Related Resource URL', with: 'somthing.com'
      select 'Article', from: 'article_resource_type'
      fill_in 'Access', with: 'some access'
      select 'Department of Biology', from: 'article_affiliation'
      fill_in 'Bibliographic citation', with: 'a citation'
      fill_in 'Copyright date', with: '2018-10-03'
      fill_in 'Date captured', with: '2018-10-03'
      fill_in 'Date other', with: '2018-10-03'
      fill_in 'Publisher-issued DOI', with: 'some doi'
      select 'Preprint', from: 'article_edition'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Funder', with: 'some funder'
      fill_in 'Geographic subject', with: 'some geographic subject'
      fill_in 'Issn', with: 'some issn'
      fill_in 'Journal issue', with: '1'
      fill_in 'Journal title', with: 'a journal'
      fill_in 'Journal volume', with: '2'
      fill_in 'Note', with: 'a note'
      fill_in 'Orcid', with: 'an orcid'
      fill_in 'Other affiliation', with: 'another affiliation'
      fill_in 'Page end', with: '32'
      fill_in 'Page start', with: '30'
      select 'Yes', from: 'article_peer_review_status'
      fill_in 'Place of publication', with: 'UNC'
      fill_in 'Rights holder', with: 'an author'
      fill_in 'Table of contents', with: 'contents'
      fill_in 'Translator', with: 'none'
      fill_in 'Link to Publisher Version', with: 'something.org'
      fill_in 'Use', with: 'some use'

      expect(page).to have_field('article_visibility_embargo')
      expect(page).not_to have_field('article_visibility_lease')
      expect(page).to have_select('article_resource_type', selected: 'Article')
      choose "article_visibility_open"
      check 'agreement'
      
      expect(page).to have_selector('#article_dcmi_type')
      expect(page).to have_selector("input[value='http://purl.org/dc/dcmitype/Text']")
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Image'

      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Administrative Set'
      find('#article_admin_set_id').text eq 'article admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'Creator Test Default Creator'
      expect(page).to have_content 'Abstract some abstract'
      expect(page).to have_content 'Date issued October 3, 2018'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'
      expect(page).to have_content 'Publisher UNC Press'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Subject test'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'Identifier some id'
      expect(page).to have_content 'Related url somthing.com'
      expect(page).to have_content 'Resource type Article'
      expect(page).to have_content 'Access some access'
      expect(page).to have_content 'Affiliation'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Bibliographic citation a citation'
      expect(page).to have_content 'Copyright date October 3, 2018'
      expect(page).to have_content 'Date captured October 3, 2018'
      expect(page).to have_content 'Date other October 3, 2018'
      expect(page).to have_content 'Doi some doi'
      expect(page).to have_content 'Edition Preprint'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Funder some funder'
      expect(page).to have_content 'Geographic subject some geographic subject'
      expect(page).to have_content 'Issn some issn'
      expect(page).to have_content 'Journal issue 1'
      expect(page).to have_content 'Journal title a journal'
      expect(page).to have_content 'Journal volume 2'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Orcid an orcid'
      expect(page).to have_content 'Other affiliation another affiliation'
      expect(page).to have_content 'Page end 32'
      expect(page).to have_content 'Page start 30'
      expect(page).to have_content 'Peer review status Yes'
      expect(page).to have_content 'Place of publication UNC'
      expect(page).to have_content 'Rights holder an author'
      expect(page).to have_content 'Table of contents contents'
      expect(page).to have_content 'Translator none'
      expect(page).to have_content 'Url something.org'
      expect(page).to have_content 'Use some use'

      expect(page).to have_content 'In Administrative Set: article admin set'
      expect(page).to have_content 'Type http://purl.org/dc/dcmitype/Image'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
