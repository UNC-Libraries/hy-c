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
      Hyrax::Workflow::PermissionGenerator.call(roles: 'deleting', workflow: workflow, agents: admin_agent)
      permission_template.available_workflows.first.update!(active: true)
      DefaultAdminSet.create(work_type_name: 'Multimed', admin_set_id: admin_set.id)

      chapel_hill = <<RDFXML.strip_heredoc
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
          <rdf:RDF xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:gn="http://www.geonames.org/ontology#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
          <gn:Feature rdf:about="http://sws.geonames.org/4460162/">
          <gn:name>Chapel Hill</gn:name>
          </gn:Feature>
          </rdf:RDF>
RDFXML
      stub_request(:get, "http://sws.geonames.org/4460162/").
          to_return(status: 200, body: chapel_hill, headers: {'Content-Type' => 'application/rdf+xml;charset=UTF-8'})
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_multimed_path
      expect(page).to have_content "Add New Multimedia"

      # required fields
      fill_in 'Title', with: 'Test Multimed'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'multimed_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'multimed_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'multimed_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'multimed_creators_attributes_0_other_affiliation' }
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Date of publication', with: '2018-10-03'
      select 'Video', from: 'multimed_resource_type'

      # extra fields
      fill_in 'Extent', with: 'some extent'
      find("#multimed_based_near_attributes_0_id", visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 3.0 United States', :from => 'multimed_license'
      fill_in 'Note', with: 'a note'
      select 'In Copyright', :from => 'multimed_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).not_to have_field('multimed_access')
      expect(page).not_to have_field('multimed_date_created')
      expect(page).not_to have_field('multimed_digital_collection')
      expect(page).not_to have_field('multimed_doi')
      expect(page).not_to have_field('multimed_medium')
      expect(page).to have_selector('#multimed_language_label', visible: false)
      expect(page).to have_selector('#multimed_license_label', visible: false)
      expect(page).to have_selector('#multimed_rights_statement_label', visible: false)
      expect(page).to have_field('multimed_visibility_embargo')
      expect(page).not_to have_field('multimed_visibility_lease')
      expect(page).not_to have_field('multimed_deposit_agreement')
      choose "multimed_visibility_open"
      check 'agreement'

      expect(page).not_to have_selector('#multimed_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Multimed'

      first('.document-title', text: 'Test Multimed').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Location Chapel Hill'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Resource type Video'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'
      expect(page).to_not have_content 'In Administrative Set: multimed admin set'
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
      fill_in 'Creator', { with: 'Test Default Creator', id: 'multimed_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'multimed_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'multimed_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'multimed_creators_attributes_0_other_affiliation' }
      fill_in 'Abstract', with: 'an abstract'
      fill_in 'Date of publication', with: '2018-10-03'
      select 'Video', from: 'multimed_resource_type'

      # extra fields
      fill_in 'Date created', with: '2018-10-03'
      fill_in 'Dcmi type', with: 'http://purl.org/dc/dcmitype/Text'
      fill_in 'Digital collection', with: 'my collection'
      fill_in 'DOI', with: 'some doi'
      fill_in 'Extent', with: 'some extent'
      find("#multimed_based_near_attributes_0_id", visible: false).set('http://sws.geonames.org/4460162/')
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'Attribution 3.0 United States', :from => 'multimed_license'
      fill_in 'Medium', with: 'a medium'
      fill_in 'Note', with: 'a note'
      select 'In Copyright', :from => 'multimed_rights_statement'
      fill_in 'Subject', with: 'test'

      expect(page).to have_selector('#multimed_language_label', visible: false)
      expect(page).to have_selector('#multimed_license_label', visible: false)
      expect(page).to have_selector('#multimed_rights_statement_label', visible: false)
      expect(page).to have_field('multimed_visibility_embargo')
      expect(page).not_to have_field('multimed_visibility_lease')
      expect(page).not_to have_field('multimed_deposit_agreement')
      choose "multimed_visibility_open"
      check 'agreement'

      expect(page).to have_selector('#multimed_dcmi_type')

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to have_content 'Administrative Set'
      find('#multimed_admin_set_id').text eq 'default admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Multimed'

      first('.document-title', text: 'Test Multimed').click
      expect(page).to have_content 'Abstract an abstract'
      expect(page).to have_content 'Creator Test Default Creator ORCID: creator orcid'
      expect(page).to have_content 'Affiliation:'
      expect(page).to have_content 'College of Arts and Sciences'
      expect(page).to have_content 'Department of Biology'
      expect(page).to have_content 'Other Affiliation: UNC'
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to_not have_content 'Type http://purl.org/dc/dcmitype/Text'
      expect(page).to have_content 'Digital collection my collection'
      expect(page).to have_content 'DOI some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'Location Chapel Hill'
      expect(page).to have_content 'Keyword Test Default Keyword'
      expect(page).to have_content 'Language English'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Note a note'
      expect(page).to have_content 'Resource type Video'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to have_content 'Subject test'
      expect(page).to_not have_content 'Language http://id.loc.gov/vocabulary/iso639-2/eng'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
