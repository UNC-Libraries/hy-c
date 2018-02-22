require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'Edit Work Types', js: false do
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
      visit work_types_path

      expect(page).to have_content "Work Types"

      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default', count: 7

      click_link 'Edit default admin sets'

      expect(page).to have_content "Edit Work Types"

      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default', count: 7

      first('tr>td>select').find(:xpath, 'option[2]').select_option

      find('input[name="commit"]').click

      expect(page).to have_content "Work Types"

      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default', count: 6
      expect(page).to have_selector 'tr>td', text: 'other admin set', count: 1
    end
  end
end
