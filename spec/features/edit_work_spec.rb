require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Edit a work', js: false do
  context 'a logged in user with an admin set' do
    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ['article admin set'],
                      description: ['some description'],
                      edit_users: [admin_user.user_key])
    end

    let(:other_admin_set) do
      AdminSet.create(title: ['other admin set'],
                      description: ['some description'],
                      edit_users: [admin_user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
    end

    let(:other_permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: other_admin_set.id)
    end

    let(:workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                              permission_template_id: permission_template.id)
    end

    let(:other_workflow) do
      Sipity::Workflow.create(name: 'test2', allows_access_grant: true, active: true,
                              permission_template_id: other_permission_template.id)
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: other_permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'deposit')
      Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
      Sipity::WorkflowAction.create(id: 5, name: 'show', workflow_id: other_workflow.id)
      DefaultAdminSet.delete_all
      DefaultAdminSet.create(work_type_name: 'Article', admin_set_id: admin_set.id)
    end

    # Administrators can change admin sets
    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_article_path
      expect(page).to have_content 'Add New Scholarly Article or Book Chapter'

      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', { with: 'Test Default Creator', id: 'article_creators_attributes_0_name' }
      fill_in 'ORCID', { with: 'creator orcid', id: 'article_creators_attributes_0_orcid' }
      select 'Department of Biology', from: 'article_creators_attributes_0_affiliation'
      fill_in 'Additional affiliation', { with: 'UNC', id: 'article_creators_attributes_0_other_affiliation' }
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'In Copyright', :from => 'article_rights_statement'
      choose 'article_visibility_open'
      check 'agreement'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link 'Add to Collection'
      expect(page).to have_content 'Administrative Set'
      find('#article_admin_set_id').text eq 'article admin set'
      find('#article_admin_set_id').select 'other admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by the Carolina Digital Repository'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: other admin set'
      expect(page).to have_selector(:link, 'Delete')

      click_link 'Edit'
      # Make sure that default admin set selector does not overwrite saved value
      find('#article_admin_set_id').text eq 'other admin set'
    end
  end

  # Do not allow works to be edited before an admin set has been created
  context 'a logged in user without an admin set' do
    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end
    
    before do
      AdminSet.delete_all
    end
    
    scenario do
      login_as admin_user
      
      visit '/'
      fill_in "search-field-header", with: 'Alice'
      click_button 'search-submit-header'

      expect(page).to have_content "Alice's Adventures in Wonderland"

      click_link "Alice's Adventures in Wonderland"

      expect(page).to have_content "Alice's Adventures in Wonderland"
      expect(page).to have_content 'Items'

      click_link 'Edit'

      expect(page).to have_content "Deposit Your Work"
      expect(page).to have_content 'No Admin Sets have been created.'
    end
  end
end
