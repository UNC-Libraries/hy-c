# frozen_string_literal: false
require 'rails_helper'
require Rails.root.join('spec/support/capybara.rb')

include Warden::Test::Helpers

RSpec.feature 'Edit works created through the Sage ingest', :sage, js: false do
  let(:ingest_progress_log_path) { File.join(fixture_path, 'sage', 'ingest_progress.log') }
  let(:path_to_config) { File.join(fixture_path, 'sage', 'sage_config.yml') }
  let(:path_to_tmp) { FileUtils.mkdir_p(File.join(fixture_path, 'sage', 'tmp')).first }
  let(:ingest_service) { Tasks::SageIngestService.new(configuration_file: path_to_config) }
  let(:article_count) { Article.count }
  let(:articles) { Article.all }
  # We're not clearing out the database, Fedora, and Solr before this test, so to find the first work created in this
  # test, we need to count backwards from the last work created.
  let(:first_work) { articles[-4] }
  let(:first_work_id) { first_work.id }
  let(:third_work_id) { articles[-2].id }

  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end

  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end

  # empty the progress log
  around(:all) do |example|
    File.open(ingest_progress_log_path, 'w') { |file| file.truncate(0) }
    example.run
    File.open(ingest_progress_log_path, 'w') { |file| file.truncate(0) }
    FileUtils.remove_entry(path_to_tmp)
  end

  before(:each) do
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).and_return(admin)
    # return the FactoryBot admin_set when searching for admin set from config
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
    # Stub background jobs that don't do well in CI
    # stub virus checking
    allow(Hydra::Works::VirusCheckerService).to receive(:file_has_virus?) { false }
    # stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    # stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
    # instantiate the sage ingest admin_set
    admin_set
    permission_template
    workflow
    workflow_state
    ingest_service.process_all_packages
  end

  context 'as a regular user' do
    let(:user) { FactoryBot.create(:user) }
    it 'gives an unauthorized message' do
      login_as user
      visit "concern/articles/#{first_work_id}/edit"
      expect(page).to have_content('Unauthorized')
    end
  end

  context 'as an admin user' do
    it 'can open the edit page' do
      login_as admin
      visit "concern/articles/#{first_work_id}"
      expect(page).to have_content('Inequalities in Cervical Cancer Screening Uptake Between')
      expect(page).to have_content('Smith, Jennifer S.')
      expect(page).to have_content('Open_Access_Articles_and_Book_Chapters')
      expect(page).to have_content('Attribution-NonCommercial 4.0 International')
      expect(page).to have_content('February 1, 2021')
      expect(page).to have_content('In Copyright')
      # expect(page).to have_button('Withdraw')
      click_link('Edit', match: :first)
      expect(page).to have_link('Work Deposit Form')
    end

    # Creator 2 only visible with Javascript on
    it 'can render the pre-populated edit page', js: true do
      login_as admin
      visit "concern/articles/#{first_work_id}/edit"
      # These values are also tested in the spec/services/tasks/sage_ingest_service_spec.rb
      # form order
      expect(page).to have_field('Title', with: 'Inequalities in Cervical Cancer Screening Uptake Between Chinese Migrant Women and Local Women: A Cross-Sectional Study')
      expect(page).to have_field('Creator #1', with: 'Holt, Hunter K.')
      # Creator 2 only visible with Javascript on
      expect(page).to have_field('Creator #2', with: 'Zhang, Xi')
      expect(page).to have_field('Additional affiliation (Creator #1)', with: 'Department of Family and Community Medicine, University of California, San Francisco, CA, USA')
      expect(page).to have_field('ORCID (Creator #1)', with: 'https://orcid.org/0000-0001-6833-8372')
      expect(page).to have_field('Abstract', with: /Efforts to increase education opportunities, provide insurance/)
      click_link('Optional fields')
      # alpha order below
      expect(page).to have_field('Copyright date', with: '2021')
      expect(page).to have_field('Date of publication', with: 'February 1, 2021') # aka date_issued
      expect(page).to have_select('Dcmi type', with_selected: 'Text')
      expect(page).to have_field('Funder', with: 'Fogarty International Center')
      expect(page).to have_field('Identifier', with: 'https://doi.org/10.1177/1073274820985792')
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
      expect(page).to have_checked_field('Public')
    end

    it 'can render values only present on the second work' do
      login_as admin
      visit "concern/articles/#{third_work_id}/edit"
      expect(page).to have_field('Title', with: /The Prevalence of Bacterial Infection in Patients Undergoing/)
      # date that includes only month and year on the edit page
      expect(page).to have_field('Date of publication', with: 'January 2021') # aka date_issued
      expect(page).to have_field('Journal issue', with: '1')
      expect(page).to have_field('Journal volume', with: '11')
      keyword_fields = page.all(:xpath, '/html/body/div[2]/div[2]/form/div/div[1]/div/div/div[1]/div[2]/div[2]/div[1]/ul/li/input')
      keywords = keyword_fields.map(&:value)
      expect(keyword_fields.count).to eq 8
      expect(keywords).to include('Propionibacterium acnes')
      expect(page).to have_select('License', with_selected: 'Attribution-NonCommercial-NoDerivatives 4.0 International')
      expect(page).to have_field('Page end', with: '20')
      expect(page).to have_field('Page start', with: '13')
    end
  end
end
