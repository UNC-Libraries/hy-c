require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'Select work type modal', js: false do
  let(:user) { FactoryBot.create(:user) }

  let(:admin_user) { FactoryBot.create(:admin) }

  before do
    ActiveFedora::Cleaner.clean!
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
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

  scenario 'as a unauthenticated on homepage' do
    visit '/'

    expect(page).to have_selector('input[value="MastersPaper"]')
    expect(page).to have_selector('input[value="HonorsThesis"]')
    expect(page).to have_selector('input[value="DataSet"]')
    expect(page).to have_selector('input[value="Article"]')
    expect(page).to have_selector('input[value="Journal"]')
    expect(page).to have_selector('input[value="ScholarlyWork"]')

    expect(page).to_not have_content'input[value="General"]'
    expect(page).to_not have_content 'Dissertations and Theses'
  end

  scenario 'as a unauthenticated on search result' do
    visit '/catalog'

    expect(page).to have_selector('input[value="MastersPaper"]')
    expect(page).to have_selector('input[value="HonorsThesis"]')
    expect(page).to have_selector('input[value="DataSet"]')
    expect(page).to have_selector('input[value="Article"]')
    expect(page).to have_selector('input[value="Journal"]')
    expect(page).to have_selector('input[value="ScholarlyWork"]')

    expect(page).to_not have_content'input[value="General"]'
    expect(page).to_not have_content 'Dissertations and Theses'
  end
end
