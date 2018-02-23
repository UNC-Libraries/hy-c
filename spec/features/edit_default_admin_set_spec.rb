require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'Create and edit default admin set', js: false do
  context 'a logged in user' do
    let(:user) do
      User.find_by_user_key('admin@example.com')
    end

    before do
      AdminSet.delete_all
      AdminSet.create(title: ["default"], description: ["some description"], edit_users: [user.user_key])
      AdminSet.create(title: ["other admin set"], description: ["some description"], edit_users: [user.user_key])
      login_as user
    end

    scenario do
      visit default_admin_sets_path

      expect(page).to have_content "Default Admin Sets"

      expect(page).to have_selector 'tr>th', text: 'Work type name'
      expect(page).to have_selector 'tr>th', text: 'Admin set title'
      expect(page).to have_selector 'tr>th', text: 'Department'
      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default', count: 7
      expect(page).to have_selector 'tr>td>a', text: 'Edit', count: 7
      expect(page).to have_selector 'tr>td>a', text: 'Delete', count: 7

      click_link 'Add new default admin set'

      expect(page).to have_content "New Default Admin Set"

      expect(page).to have_content 'Work type name'
      expect(page).to have_selector '#default_admin_set_work_type_name', text: 'Work'
      expect(page).to have_content 'Admin set'
      expect(page).to have_selector '#default_admin_set_admin_set_id', text: 'default'
      expect(page).to have_content 'Department (only available for masters papers)'
      expect(page).to have_selector '#default_admin_set_department', text: ''
      expect(page).to have_content 'Cancel'

      select 'Journal', from: 'Work type name'
      select 'Art History Program', from: 'default_admin_set[department]'

      find('input[name="commit"]').click

      expect(page).to have_content "Default Admin Sets"

      expect(page).to have_selector 'tr>th', text: 'Work type name'
      expect(page).to have_selector 'tr>th', text: 'Admin set title'
      expect(page).to have_selector 'tr>th', text: 'Department'
      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Art History Program'
      expect(page).to have_selector 'tr>td', text: 'default', count: 8

      first(:link, 'Edit').click

      expect(page).to have_content "Edit Default Admin Set"

      expect(page).to have_content 'Work type name'
      expect(page).to have_selector '#default_admin_set_work_type_name', text: 'Work'
      expect(page).to have_content 'Admin set'
      expect(page).to have_selector '#default_admin_set_admin_set_id', text: 'default'
      expect(page).to have_content 'Department (only available for masters papers)'
      expect(page).to have_selector '#default_admin_set_department', text: ''
      expect(page).to have_content 'Cancel'

      select 'other admin set', from: 'Admin set'

      find('input[name="commit"]').click

      expect(page).to have_content "Default Admin Sets"

      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal', count: 2
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default', count: 7
      expect(page).to have_selector 'tr>td', text: 'other admin set', count: 1
    end
  end
end
