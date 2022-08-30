# frozen_string_literal: true
require 'rails_helper'
include Warden::Test::Helpers
require 'active_fedora/cleaner'
require Rails.root.join('spec/support/capybara.rb')

# testing overrides
RSpec.feature 'Edit a batch of works', js: false do
  let(:user) { FactoryBot.create(:user) }
  let(:admin_user) { FactoryBot.create(:admin) }

  context 'as a logged in regular user' do
    scenario 'cannot perform batch edit' do
      login_as user
      visit hyrax.edit_batch_edits_path
      expect(page).to have_content 'Batch operations are not allowed.'
    end
  end

  context 'as a logged in admin user' do
    scenario 'cannot perform batch edit' do
      login_as admin_user
      visit hyrax.edit_batch_edits_path
      expect(page).to have_content 'Batch operations are not allowed.'
    end
  end

  context 'with work present' do
    let(:work) { FactoryBot.create(:article, title: ['Adventures in Hyc-land']) }
    before do
      ActiveFedora::Cleaner.clean!
      Blacklight.default_index.connection.delete_by_query('*:*')
      Blacklight.default_index.connection.commit
      work
    end

    scenario 'select a work and check for batch operations', js: true do
      login_as admin_user
      visit 'dashboard/my/works'

      page.check('batch_document_ids[]')

      # Need to wait for the batch operation panel to appear after selecting work
      find('.batch-toggle', wait: 5)
      expect(page).to have_content 'Add to collection'
      expect(page).not_to have_selector("input[type=submit][value='Delete Selected']")
      expect(page).not_to have_selector("input[type=submit][value='Edit Selected']")
    end
  end
end
