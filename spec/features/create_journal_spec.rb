# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a Journal', js: false do
  context 'a logged in user' do
    let(:user_attributes) do
      { email: 'test@example.com', guest: false }
    end

    let(:admin_user) do
      User.find_by_user_key('admin@example.com')
    end

    let(:user) do
      User.new(user_attributes) { |u| u.save(validate: false) }
    end

    let(:admin_set) do
      AdminSet.create(title: ["journal admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end
    
    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(admin_set_id: admin_set.id)
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
      DefaultAdminSet.create(work_type_name: 'Journal', admin_set_id: admin_set.id)
    end

    scenario 'as a non-admin' do
      login_as user

      visit new_hyrax_journal_path
      expect(page).to have_content "Add New Scholarly Journal, Newsletter or Book"

      fill_in 'Title', with: 'Test Journal'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", :from => "journal_rights_statement"
      expect(page).to have_field('journal_visibility_embargo')
      expect(page).not_to have_field('journal_visibility_lease')
      choose "journal_visibility_open"
      check 'agreement'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to_not have_content 'Add as member of administrative set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Journal'

      first('.document-title', text: 'Test Journal').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: journal admin set'
    end

    scenario 'as an admin' do
      login_as admin_user

      visit new_hyrax_journal_path
      expect(page).to have_content "Add New Scholarly Journal, Newsletter or Book"

      fill_in 'Title', with: 'Test Journal'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", :from => "journal_rights_statement"
      expect(page).to have_field('journal_visibility_embargo')
      expect(page).not_to have_field('journal_visibility_lease')
      choose "journal_visibility_open"
      check 'agreement'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_link "Relationships"
      expect(page).to have_content 'Add as member of administrative set'
      find('#journal_admin_set_id').text eq 'journal admin set'

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Journal'

      first('.document-title', text: 'Test Journal').click
      expect(page).to have_content 'Test Default Keyword'
      expect(page).to have_content 'In Administrative Set: journal admin set'
    end
  end
end
