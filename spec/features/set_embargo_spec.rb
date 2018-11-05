require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set 'js: true'
RSpec.feature 'Edit embargo', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:admin_set) do
      AdminSet.create(title: ['article admin set'],
                      description: ['some description'],
                      edit_users: [user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(source_id: admin_set.id, release_period: '6mos')
    end

    let(:workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                              permission_template_id: permission_template.id)
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: user.user_key,
                                             access: 'deposit')
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                             agent_type: 'user',
                                             agent_id: admin_user.user_key,
                                             access: 'deposit')
      Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
      DefaultAdminSet.create(work_type_name: 'Article', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin with an invalid release date' do
      login_as user

      visit new_hyrax_article_path
      expect(page).to have_content 'Add New Scholarly Article or Book Chapter'

      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'In Copyright', :from => 'article_rights_statement'
      choose 'article_visibility_embargo'
      check 'agreement'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link 'Relationships'
      expect(page).to_not have_content 'Add as member of administrative set'

      fill_in 'article_embargo_release_date', with: DateTime.now+7.months
      click_button 'Save'
      expect(page).to have_content 'Embargo release date Release date specified does not match permission template release requirements for selected AdminSet'

      # Hyrax empties the form
      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'In Copyright', :from => 'article_rights_statement'
      choose 'article_visibility_embargo'
      check 'agreement'


      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      fill_in 'article_embargo_release_date', with: DateTime.now+5.months
      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Unauthorized The page you have tried to access is private'
    end

    scenario 'as an admin with an invalid release date' do
      login_as admin_user

      visit new_hyrax_article_path
      expect(page).to have_content 'Add New Scholarly Article or Book Chapter'

      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select 'In Copyright', :from => 'article_rights_statement'
      choose 'article_visibility_embargo'
      check 'agreement'

      find('label[for=addFiles]').click do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'), make_visible: true)
      end

      click_link 'Relationships'
      expect(page).to have_content 'Administrative Set'
      find('#article_admin_set_id').text eq 'article admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: article admin set'
      expect(page).to have_selector(:link, 'Delete')
      expect(page).to have_content 'Embargo release date '+(DateTime.now+1.day).humanize

      click_link 'Edit'
      fill_in 'article_embargo_release_date', with: DateTime.now+7.months
      click_button 'Save'
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: article admin set'
      expect(page).to have_content 'Embargo release date '+(DateTime.now+7.months).humanize
    end
  end
end
