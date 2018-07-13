require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'Select work type modal', js: false do
  let(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
  end

  let(:admin_user) do
    User.find_by_user_key('admin@example.com')
  end

  # Work type selector modal is auto-loaded on the homepage
  scenario 'as a non-admin' do
    login_as user

    visit '/'
    expect(page).to_not have_content 'Dissertations and Theses'
  end

  scenario 'as an admin' do
    login_as admin_user

    visit hyrax.dashboard_works_path
    expect(page).to have_content 'Dissertations and Theses'
  end
end
