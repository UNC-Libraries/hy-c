# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Tasks::EricIngest::Backlog::Utilities::AttributeBuilders::EricAttributeBuilder do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:article) { FactoryBot.build(:article) }
  let(:config) { { 'depositor_onyen' => depositor.uid } }

  let(:metadata) do
    {
        'title' => 'Sample Eric Article',
        'description' => 'This is a sample abstract for an Eric article.',
        'eric_id' => 'ED123456',
        'publisher' => 'Sample Publisher',
        'publicationdateyear' => '2023',
        'subject' => ['Education', 'Research'],
        'author' => [
            'Doe, John',
            'Smith, Jane'
        ],
        'issn' => ['ISSN-1234-5678'],
    }
  end

  subject(:builder) { described_class.new(metadata, admin_set, depositor.uid) }

  before do
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '#get_date_issued' do
    it 'returns a formatted date string when publication year is present' do
      expect(builder.get_date_issued).to eq(DateTime.new(2023).strftime('%Y-%m-%d'))
    end

    it 'returns nil if publication year is missing' do
      metadata.delete('publicationdateyear')
      expect(builder.get_date_issued).to be_nil
    end
  end

  describe '#generate_authors' do
    it 'returns an array of author hashes with names and indices' do
      authors = builder.send(:generate_authors)
      expect(authors.length).to eq(2)
      expect(authors[0]).to eq({ 'name' => 'Doe, John', 'index' => '0' })
      expect(authors[1]).to eq({ 'name' => 'Smith, Jane', 'index' => '1' })
    end

    it 'returns default value if no authors are present' do
      metadata.delete('author')
      authors = builder.send(:generate_authors)
      expect(authors[0]).to eq({ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' })
    end
  end

  describe '#apply_additional_basic_attributes' do
    it 'assigns core article attributes from metadata' do
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.title).to eq(['Sample Eric Article'])
      expect(article.abstract).to eq(['This is a sample abstract for an Eric article.'])
      expect(article.date_issued).to eq('2023-01-01')
      expect(article.publisher).to eq(['Sample Publisher'])
      expect(article.keyword).to eq(['Education', 'Research'])
    end
  end

  describe '#set_identifiers' do
    it 'builds identifiers and ISSNs correctly' do
      builder.send(:set_identifiers, article)

      expect(article.identifier).to eq(['ERIC ID: ED123456'])
      expect(article.issn).to eq(['1234-5678'])
    end

    it 'handles missing eric_id and issn gracefully' do
      metadata.delete('eric_id')
      metadata.delete('issn')
      builder.send(:set_identifiers, article)

      expect(article.identifier).to eq([])
      expect(article.issn).to eq([])
    end
  end
end
