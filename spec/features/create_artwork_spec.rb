# Generated via
#  `rails generate hyrax:work Artwork`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create an Artwork', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ["artwork admin set"],
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
      DefaultAdminSet.create(work_type_name: 'Artwork', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_artwork_path
      expect(page).to have_content "Add New Artwork"

      # required fields
      fill_in 'Title', with: 'Test Artwork work'
      fill_in 'Date of publication', with: '2018-10-03'
      fill_in 'Abstract', with: 'a description'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Medium', with: 'a medium'

      # extra fields

      fill_in 'DOI', with: 'some doi'
      select 'Attribution 3.0 United States', :from => 'artwork_license'
      select 'In Copyright', :from => 'artwork_rights_statement'

      expect(page).to have_selector('#artwork_license_label', visible: false)
      expect(page).to have_selector('#artwork_rights_statement_label', visible: false)
      expect(page).to have_field('artwork_visibility_embargo')
      expect(page).not_to have_field('artwork_date_created')
      expect(page).not_to have_field('artwork_visibility_lease')
      expect(page).to have_select('artwork_resource_type', selected: 'Art')
      choose "artwork_visibility_open"

      check 'agreement'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to_not have_content 'Administrative Set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Artwork work'

      first('.document-title', text: 'Test Artwork work').click
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Abstract a description'
      expect(page).to have_content 'DOI some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Resource type Art'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to_not have_content 'In Administrative Set: artwork admin set'
      expect(page).to_not have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_artwork_path
      expect(page).to have_content "Add New Artwork"

      # required fields
      fill_in 'Title', with: 'Test Artwork work'
      fill_in 'Date created', with: '2018-10-03'
      fill_in 'Date of publication', with: '2018-10-03'
      fill_in 'Abstract', with: 'a description'
      fill_in 'Extent', with: 'some extent'
      fill_in 'Medium', with: 'a medium'

      # extra fields
      fill_in 'DOI', with: 'some doi'
      select 'Attribution 3.0 United States', :from => 'artwork_license'
      select 'In Copyright', :from => 'artwork_rights_statement'

      expect(page).to have_selector('#artwork_license_label', visible: false)
      expect(page).to have_selector('#artwork_rights_statement_label', visible: false)
      expect(page).to have_field('artwork_visibility_embargo')
      expect(page).not_to have_field('artwork_visibility_lease')
      choose "artwork_visibility_open"

      check 'agreement'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link "Add to Collection"
      expect(page).to have_content 'Administrative Set'
      find('#artwork_admin_set_id').text eq 'artwork admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Artwork work'

      first('.document-title', text: 'Test Artwork work').click
      expect(page).to have_content 'Date created October 3, 2018'
      expect(page).to have_content 'Date of publication October 3, 2018'
      expect(page).to have_content 'Abstract a description'
      expect(page).to have_content 'DOI some doi'
      expect(page).to have_content 'Extent some extent'
      expect(page).to have_content 'License Attribution 3.0 United States'
      expect(page).to have_content 'Medium a medium'
      expect(page).to have_content 'Resource type Art'
      expect(page).to have_content 'Rights statement In Copyright'
      expect(page).to_not have_content 'License http://creativecommons.org/licenses/by/3.0/us/'
      expect(page).to_not have_content 'Rights statement http://rightsstatements.org/vocab/InC/1.0/'

      expect(page).to have_content 'In Administrative Set: artwork admin set'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'

      expect(page).to have_content 'Edit Work'
    end
  end
end
