# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/full_text.rb')
require Rails.root.join('spec/support/oai_sample_solr_documents.rb')
include Warden::Test::Helpers

RSpec.describe 'Advanced search', type: :feature, js: false do
  let(:solr) { Blacklight.default_index.connection }
  let(:smith_work) do
    FULL_TEXT_WORK.merge(
      'id' => 'smith-thesis-work',
      'title_tesim' => ['Smith thesis target'],
      'title_sort_ssi' => 'smith thesis target',
      'file_set_ids_ssim' => ['smith-thesis-file-set'],
      'member_ids_ssim' => ['smith-thesis-file-set'],
      'creator_tesim' => ['smith'],
      'creator_sim' => ['smith'],
      'creator_label_tesim' => ['smith'],
      'creator_label_sim' => ['smith']
    )
  end

  let(:smith_file_set) do
    FULL_TEXT_FILE_SET.merge(
      'id' => 'smith-thesis-file-set',
      'title_tesim' => ['smith-thesis.pdf'],
      'label_tesim' => ['smith-thesis.pdf'],
      'label_ssi' => 'smith-thesis.pdf',
      'all_text_timv' => ['thesis']
    )
  end

  let(:jones_work) do
    FULL_TEXT_WORK.merge(
      'id' => 'jones-thesis-work',
      'title_tesim' => ['Jones thesis decoy'],
      'title_sort_ssi' => 'jones thesis decoy',
      'file_set_ids_ssim' => ['jones-thesis-file-set'],
      'member_ids_ssim' => ['jones-thesis-file-set'],
      'creator_tesim' => ['jones'],
      'creator_sim' => ['jones'],
      'creator_label_tesim' => ['jones'],
      'creator_label_sim' => ['jones']
    )
  end

  let(:jones_file_set) do
    FULL_TEXT_FILE_SET.merge(
      'id' => 'jones-thesis-file-set',
      'title_tesim' => ['jones-thesis.pdf'],
      'label_tesim' => ['jones-thesis.pdf'],
      'label_ssi' => 'jones-thesis.pdf',
      'all_text_timv' => ['thesis']
    )
  end

  before do
    solr.delete_by_query('*:*') # delete everything in Solr
    solr.add([
               SLEEPY_HOLLOW,
               MYSTERIOUS_AFFAIR,
               BEOWULF,
               LEVIATHAN,
               GREAT_EXPECTATIONS,
               ILIAD,
               MISERABLES,
               MOBY_DICK,
               smith_work,
               smith_file_set,
               jones_work,
               jones_file_set
             ])
    solr.commit
  end

  after do
    solr.delete_by_query('*:*')
    solr.commit
  end

  it 'date range field returns expected results and retains values' do
    visit '/catalog/advanced'
    fill_in('range_date_issued_isim_begin', with: '1990')
    fill_in('range_date_issued_isim_end', with: '2020')
    click_button('Search')
    # Verify that only the titles with date issued within the given range are returned
    expect(page).not_to have_content(SLEEPY_HOLLOW[:title_tesim][0])
    expect(page).not_to have_content(MYSTERIOUS_AFFAIR[:title_tesim][0])
    expect(page).not_to have_content(BEOWULF[:title_tesim][0])
    expect(page).not_to have_content(LEVIATHAN[:title_tesim][0])
    expect(page).to have_content(GREAT_EXPECTATIONS[:title_tesim][0])
    expect(page).not_to have_content(ILIAD[:title_tesim][0])
    expect(page).to have_content(MISERABLES[:title_tesim][0])
    expect(page).to have_content(MOBY_DICK[:title_tesim][0])
    # Return to the advanced search and verify that the date range is still present
    click_link('Advanced search', match: :first)
    expect(page).to have_content('Date:1990 to 2020')
    expect(find('#range_date_issued_isim_begin').value).to eq('1990')
    expect(find('#range_date_issued_isim_end').value).to eq('2020')
  end

  it 'uses the creator clause to narrow all fields results' do
    visit search_catalog_path(
      op: 'must',
      clause: {
        '0' => { field: 'all_fields', query: 'thesis' },
        '1' => { field: 'creator', query: 'smith' }
      }
    )

    expect(page).to have_current_path(/\/catalog\?/)
    expect(page).to have_content('Smith thesis target')
    expect(page).not_to have_content('Jones thesis decoy')
  end

end
