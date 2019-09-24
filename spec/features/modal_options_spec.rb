require 'rails_helper'
include Warden::Test::Helpers

# checking modal options for admins and non-admins
RSpec.feature 'Modal options', js: false do
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

      expect(page).to have_content 'Select type of work'
      expect(page).to have_content "Master's Paper"
      expect(page).to have_content 'Scholarly Articles and Book Chapters'
      expect(page).to have_content 'Undergraduate Honors Theses'
      expect(page).to have_content 'Scholarly Journal, Newsletter or Book'
      expect(page).to have_content 'Datasets'
      expect(page).to have_content 'Multimedia'
      expect(page).to have_content 'Poster, Presentation or Paper'
      expect(page).not_to have_content 'Dissertations and Theses'
      expect(page).not_to have_content 'General'
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

      expect(page).to have_content 'Select type of work'
      expect(page).to have_content "Master's Paper"
      expect(page).to have_content 'Scholarly Articles and Book Chapters'
      expect(page).to have_content 'Undergraduate Honors Theses'
      expect(page).to have_content 'Scholarly Journal, Newsletter or Book'
      expect(page).to have_content 'Datasets'
      expect(page).to have_content 'Multimedia'
      expect(page).to have_content 'Poster, Presentation or Paper'
      expect(page).to have_content 'Dissertations and Theses'
      expect(page).to have_content 'General'
    end
  end
end
