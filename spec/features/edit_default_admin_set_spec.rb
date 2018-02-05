require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'Edit Work Types', js: false do
  context 'a logged in user' do
    let(:user) {
      User.find_by_user_key('admin@example.com')
    }

    let(:default_admin_set) {
      AdminSet.create(title: ["default admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    }

    let(:other_admin_set) {
      AdminSet.create(title: ["other admin set"],
                      description: ["some description"],
                      edit_users: [user.user_key])
    }

    before do
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
      expect(page).to have_selector 'tr>td', text: 'default admin set', count: 6

      click_link 'Edit default admin sets'

      expect(page).to have_content "Edit Work Types"

      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default admin set', count: 6

      first('tr>td>select').find(:xpath, 'option[2]').select_option

      find('input[name="commit"]').click

      expect(page).to have_content "Work Types"

      expect(page).to have_selector 'tr>td', text: 'Work'
      expect(page).to have_selector 'tr>td', text: 'Journal'
      expect(page).to have_selector 'tr>td', text: 'Article'
      expect(page).to have_selector 'tr>td', text: 'HonorsThesis'
      expect(page).to have_selector 'tr>td', text: 'MastersPaper'
      expect(page).to have_selector 'tr>td', text: 'Dissertation'
      expect(page).to have_selector 'tr>td', text: 'default admin set', count: 6
    end
  end
end
