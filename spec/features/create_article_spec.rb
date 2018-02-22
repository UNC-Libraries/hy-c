# Generated via
#  `rails generate hyrax:work Article`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'Create a Article', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com',guest: false) { |u| u.save!(validate: false)}
    end

    let(:admin_set) do
      AdminSet.create(title: ["default admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    end

    let(:permission_template) do
      Hyrax::PermissionTemplate.create!(admin_set_id: admin_set.id)
    end

    let(:workflow) do
      Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true, permission_template_id: permission_template.id)
    end

    before do
      Hyrax::PermissionTemplateAccess.create(permission_template: permission_template, agent_type: 'user', agent_id: user.user_key, access: 'deposit')
      Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
      WorkType.create(work_type_name: 'Article', admin_set_id: admin_set.id)
      login_as user
    end

    scenario do
      visit new_hyrax_article_path
      expect(page).to have_content "Add New Article"

      fill_in 'Title', with: 'Test Article work'
      fill_in 'Creator', with: 'Test Default Creator'
      fill_in 'Keyword', with: 'Test Default Keyword'
      select "In Copyright", :from => "article_rights_statement"
      choose "article_visibility_open"
      check 'agreement'

      click_link "Files" # switch tab
      within "//span[@id=addfiles]" do
        attach_file('files[]', File.join(Rails.root, '/spec/fixtures/files/test.txt'))
      end

      click_button 'Save'
      expect(page).to have_content 'Your files are being processed by Hyrax'

      visit '/dashboard/my/works/'
      expect(page).to have_content 'Test Article work'

      first('.document-title', text: 'Test Article work').click
      expect(page).to have_content 'Test Default Keyword'
    end
  end
end
