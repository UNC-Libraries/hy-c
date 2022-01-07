require 'rails_helper'
require Rails.root.join('spec/support/capybara.rb')

include Warden::Test::Helpers

RSpec.feature 'Edit works created through the Sage ingest', js: false do
  let(:ingest_service) { Tasks::SageIngestService.new(configuration_file: path_to_config) }
  let(:ingest_progress_log_path) { File.join(fixture_path, "sage", "ingest_progress.log") }
  let(:path_to_config) { File.join(fixture_path, "sage", "sage_config.yml") }
  let(:admin_user) { FactoryBot.create(:admin) }

  let(:article_count) { Article.count }
  let(:articles) { Article.all.to_ary }
  let(:last_work_id) { articles[article_count-4].id }

  let(:admin_set) do
    AdminSet.create(title: ['sage admin set'],
                    description: ['some description'],
                    edit_users: [admin_user.user_key])
  end

  # empty the progress log
  around do |example|
    File.open(ingest_progress_log_path, 'w') {|file| file.truncate(0) }
    example.run
    File.open(ingest_progress_log_path, 'w') {|file| file.truncate(0) }
  end

  before do
    admin_set
    ingest_service.process_packages
    login_as admin_user
  end

  it "can open the edit page" do
    visit "concern/articles/#{last_work_id}"
    expect(page).to have_content("Inequalities in Cervical Cancer Screening Uptake Between")
    expect(page).to have_content('Smith, Jennifer S.')
    click_link('Edit')
    expect(page).to have_link("Work Deposit Form")
  end

  it "can render the pre-populated edit page" do
    visit "concern/articles/#{last_work_id}/edit"
    expect(page).to have_field('Title', with: 'Inequalities in Cervical Cancer Screening Uptake Between Chinese Migrant Women and Local Women: A Cross-Sectional Study')
    expect(page).to have_field('Creator #1', with: 'Holt, Hunter K.')
    expect(page).to have_field('Abstract', with: /Efforts to increase education opportunities, provide insurance/)
    expect(page).to have_field('Date of publication', with: 'February 1, 2021')
    click_link('Optional fields')
    expect(page).to have_field('Identifier', with: '10.1177/1073274820985792')
    expect(page).to have_field('ISSN', with: '1073-2748')
    expect(page).to have_field('Journal title', with: 'Cancer Control')
  end

  it "can render the javascript-drawn fields", js: true do
    expected_keywords = ['HPV', 'HPV knowledge and awareness', 'cervical cancer screening', 'migrant women', 'China', '']
    visit "concern/articles/#{last_work_id}/edit"
    click_link('Optional fields')
    keyword_wrapper = page.find(:xpath, '//*[@id="extended-terms"]/div[1]')
    scroll_to(keyword_wrapper, align: :top)
    keyword_fields = page.all(:xpath, '/html/body/div[2]/div[2]/form/div/div[1]/div/div/div[1]/div[2]/div[2]/div[1]/ul/li/input')
    keywords = keyword_fields.map(&:value)
    expect(keyword_fields.count).to eq 6
    expect(keywords).to match_array(expected_keywords)
  end

  it "can render the populated controlled vocabulary" do
    visit "concern/articles/#{last_work_id}/edit"
    click_link('Optional fields')
    expect(page).to have_select('Dcmi type', with_selected: 'Text')
    expect(page).to have_select('License', with_selected: 'Attribution-NonCommercial 4.0 International')
    expect(page).to have_select('Rights statement', with_selected: 'In Copyright')
  end
end
