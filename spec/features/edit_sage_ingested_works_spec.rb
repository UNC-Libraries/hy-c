require 'rails_helper'
require Rails.root.join('spec/support/capybara.rb')

include Warden::Test::Helpers

RSpec.feature 'Edit works created through the Sage ingest', js: false do
  let(:ingest_progress_log_path) { File.join(fixture_path, "sage", "ingest_progress.log") }

  # empty the progress log
  around do |example|
    File.open(ingest_progress_log_path, 'w') {|file| file.truncate(0) }
    example.run
    File.open(ingest_progress_log_path, 'w') {|file| file.truncate(0) }
  end

  before(:all) do
    @admin_user = FactoryBot.create(:admin)
    @admin_set = AdminSet.create(title: ['sage admin set'],
                                 description: ['some description'],
                                 edit_users: [@admin_user.user_key])
    @path_to_config = File.join(fixture_path, "sage", "sage_config.yml")

    @ingest_service = Tasks::SageIngestService.new(configuration_file: @path_to_config)
    @ingest_service.process_packages

    @article_count = Article.count
    @articles = Article.all
    @first_work = @articles[-4]
    @first_work_id = @first_work.id
    @second_work_id = @articles[-2].id
  end

  it "can open the edit page" do
    login_as @admin_user
    visit "concern/articles/#{@first_work_id}"
    expect(page).to have_content("Inequalities in Cervical Cancer Screening Uptake Between")
    expect(page).to have_content('Smith, Jennifer S.')
    click_link('Edit')
    expect(page).to have_link("Work Deposit Form")
  end

  it "has attached the file_set to the work" do
    pending("Adding file sets to the Article object")
    expect(@first_work.file_sets.first).to be_instance_of(FileSet)
  end

  it "can render the pre-populated edit page" do
    login_as @admin_user
    visit "concern/articles/#{@first_work_id}/edit"
    # These values are also tested in the spec/services/tasks/sage_ingest_service_spec.rb
    # form order
    expect(page).to have_field('Title', with: 'Inequalities in Cervical Cancer Screening Uptake Between Chinese Migrant Women and Local Women: A Cross-Sectional Study')
    expect(page).to have_field('Creator #1', with: 'Holt, Hunter K.')
    expect(page).to have_field('Additional affiliation (Creator #1)', with: 'Department of Family and Community Medicine, University of California, San Francisco, CA, USA')
    expect(page).to have_field('ORCID (Creator #1)', with: 'https://orcid.org/0000-0001-6833-8372')
    expect(page).to have_field('Abstract', with: /Efforts to increase education opportunities, provide insurance/)
    click_link('Optional fields')
    # alpha order below
    expect(page).to have_field('Copyright date', with: '2021')
    expect(page).to have_field('Date of publication', with: 'February 1, 2021') # aka date_issued
    expect(page).to have_select('Dcmi type', with_selected: 'Text')
    expect(page).to have_field('Funder', with: 'Fogarty International Center')
    expect(page).to have_field('Identifier', with: '10.1177/1073274820985792')
    expect(page).to have_field('ISSN', with: '1073-2748')
    expect(page).to have_field('Journal issue', with: '')
    expect(page).to have_field('Journal title', with: 'Cancer Control')
    expect(page).to have_field('Journal volume', with: '28')
    # keywords
    expected_keywords = ['HPV', 'HPV knowledge and awareness', 'cervical cancer screening', 'migrant women', 'China', '']
    keyword_fields = page.all(:xpath, '/html/body/div[2]/div[2]/form/div/div[1]/div/div/div[1]/div[2]/div[2]/div[1]/ul/li/input')
    keywords = keyword_fields.map(&:value)
    expect(keyword_fields.count).to eq 6
    expect(keywords).to match_array(expected_keywords)
    expect(page).to have_select('License', with_selected: 'Attribution-NonCommercial 4.0 International')
    expect(page).to have_field('Publisher', with: 'SAGE Publications')
    expect(page).to have_select('Resource type', with_selected: 'Article')
    expect(page).to have_field('Rights holder', with: /SAGE Publications Inc, unless otherwise noted. Manuscript/)
    expect(page).to have_select('Rights statement', with_selected: 'In Copyright')
  end

  # creators after the first one need JS to render
  it "can render the javascript-drawn fields", js: true do
    login_as @admin_user
    visit "concern/articles/#{@first_work_id}/edit"
    expect(page).to have_field('Creator #2', with: 'Zhang, Xi')
  end

  it "can render values only present on the second work" do
    login_as @admin_user
    visit "concern/articles/#{@second_work_id}/edit"
    expect(page).to have_field('Title', with: /The Prevalence of Bacterial Infection in Patients Undergoing/)
    expect(page).to have_field('Journal issue', with: '1')
    expect(page).to have_field('Journal volume', with: '11')
    keyword_fields = page.all(:xpath, '/html/body/div[2]/div[2]/form/div/div[1]/div/div/div[1]/div[2]/div[2]/div[1]/ul/li/input')
    keywords = keyword_fields.map(&:value)
    expect(keyword_fields.count).to eq 8
    expect(keywords).to include('Propionibacterium acnes')
    expect(page).to have_field('Page end', with: '20')
    expect(page).to have_field('Page start', with: '13')
  end
end
