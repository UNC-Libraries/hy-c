require 'rails_helper'
include Warden::Test::Helpers

RSpec.feature 'redirect doi urls', js: false do
  context 'for models with two-word names' do
    let(:honors_thesis) { HonorsThesis.create(title: ['honors thesis doi test'], visibility: 'open')}
    let(:masters_paper) { MastersPaper.create(title: ['masters paper doi test'], visibility: 'open')}
    let(:data_set) { DataSet.create(title: ['data set doi test'], visibility: 'open')}
    let(:scholarly_work) { ScholarlyWork.create(title: ['scholaraly work doi test'], visibility: 'open')}

    scenario 'when doi links are wrong' do
      # original doi url generation
      honors_thesis_doi = "#{ENV['HYRAX_HOST']}/concern/#{Array.wrap(honors_thesis.class.to_s).first.downcase}s/#{honors_thesis.id}?locale=en"
      visit honors_thesis_doi
      expect(page).to have_content honors_thesis.title.first

      masters_paper_doi = "#{ENV['HYRAX_HOST']}/concern/#{Array.wrap(masters_paper.class.to_s).first.downcase}s/#{masters_paper.id}?locale=en"
      visit masters_paper_doi
      expect(page).to have_content masters_paper.title.first

      data_set_doi = "#{ENV['HYRAX_HOST']}/concern/#{Array.wrap(data_set.class.to_s).first.downcase}s/#{data_set.id}?locale=en"
      visit data_set_doi
      expect(page).to have_content data_set.title.first

      scholarly_work_doi = "#{ENV['HYRAX_HOST']}/concern/#{Array.wrap(scholarly_work.class.to_s).first.downcase}s/#{scholarly_work.id}?locale=en"
      visit scholarly_work_doi
      expect(page).to have_content scholarly_work.title.first
    end
  end
end