# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/helpers/hyrax/citations_behaviors/publication_behavior_override.rb')

RSpec.describe Hyrax::CitationsBehaviors::PublicationBehavior, type: :helper do
  let(:work_with_date_issued) {
    Article.new(title: ['new article title'],
                date_issued: '2019-10-11',
                abstract: ['Test Abstract'],
                creators_attributes: { '0' => { name: 'Test, Person',
                                                affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                index: 1 } })
  }

  let(:work_with_multiple_date_issued) {
    General.new(title: ['new article title'], date_issued: ['2011-01-01', '2012-04-12'])
  }

  let(:work_without_date_issued) {
    General.new(title: ['new article title'])
  }

  let(:work_with_bad_date_issued) {
    Article.new(title: ['new article title'],
                date_issued: 'bad date',
                abstract: ['Test Abstract'],
                creators_attributes: { '0' => { name: 'Test, Person',
                                                affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                index: 1 } })
  }

  it 'returns a formatted date from date issued' do
    expect(helper.setup_pub_date(work_with_date_issued)).to eq '2019'
  end

  it 'returns a formatted date for multiple date issued' do
    expect(helper.setup_pub_date(work_with_multiple_date_issued)).to eq '2011'
  end

  it 'does not return a formatted date from date issued if one is not present' do
    expect(helper.setup_pub_date(work_without_date_issued)).to eq nil
  end

  it 'does not return a formatted date for invalid dates' do
    expect(helper.setup_pub_date(work_with_bad_date_issued)).to eq nil
  end
end
