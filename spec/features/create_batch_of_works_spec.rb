require 'rails_helper'
include Warden::Test::Helpers

# testing overrides
RSpec.feature 'Create a batch of works', js: false do
  context 'a logged in user' do
    let(:user) do
      User.new(email: 'test@example.com', guest: false, uid: 'test') { |u| u.save!(validate: false)}
    end

    let(:admin_user) do
      User.find_by_user_key('admin')
    end

    scenario 'as a non-admin' do
      login_as user
      visit root_path
      expect(page).to have_content user.uid

      within("//ul[@id='user_utility_links']") do
        click_link 'Dashboard'
      end
      expect(page).to have_content 'Dashboard'
      expect(page).to have_content 'User Activity'

      click_link 'Works'
      expect(page).to have_content 'works you own in the repository'

      visit hyrax.edit_batch_edits_path
      expect(page).to have_content 'Batch operations are not allowed.'
    end

    scenario 'as an admin' do
      login_as admin_user
      visit root_path
      expect(page).to have_content admin_user.uid

      within("//ul[@id='user_utility_links']") do
        click_link 'Dashboard'
      end
      expect(page).to have_content 'Dashboard'
      expect(page).to have_content 'User Activity'

      click_link 'Works'
      expect(page).to have_content 'works you own in the repository'

      visit hyrax.edit_batch_edits_path
      expect(page).to have_content 'Batch operations are not allowed.'
    end
  end
end
