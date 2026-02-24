# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Journal do
  it 'has a title' do
    subject.title = ['journal']
    expect(subject.title).to eq ['journal']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_journal' }
  end

  describe 'metadata' do
    it 'has metadata' do
      expect(subject).to respond_to(:relative_path)
      expect(subject).to respond_to(:depositor)
      expect(subject).to respond_to(:contributor)
      expect(subject).to respond_to(:contributors)
      expect(subject).to respond_to(:creator)
      expect(subject).to respond_to(:creators)
      expect(subject).to respond_to(:title)
      expect(subject).to respond_to(:label)
      expect(subject).to respond_to(:keyword)
      expect(subject).to respond_to(:publisher)
      expect(subject).to respond_to(:date_created)
      expect(subject).to respond_to(:date_uploaded)
      expect(subject).to respond_to(:date_modified)
      expect(subject).to respond_to(:based_near)
      expect(subject).to respond_to(:subject)
      expect(subject).to respond_to(:language)
      expect(subject).to respond_to(:license)
      expect(subject).to respond_to(:rights_statement)
      expect(subject).to respond_to(:identifier)
      expect(subject).to respond_to(:source)
      expect(subject).to respond_to(:resource_type)
      expect(subject).to respond_to(:related_url)
      expect(subject).to respond_to(:access_right)
      expect(subject).to respond_to(:rights_notes)

      # Custom fields
      expect(subject).to respond_to(:abstract)
      expect(subject).to respond_to(:admin_note)
      expect(subject).to respond_to(:alternative_title)
      expect(subject).to respond_to(:date_issued)
      expect(subject).to respond_to(:deposit_agreement)
      expect(subject).to respond_to(:deposit_record)
      expect(subject).to respond_to(:doi)
      expect(subject).to respond_to(:edition)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:dcmi_type)
      expect(subject).to respond_to(:digital_collection)
      expect(subject).to respond_to(:isbn)
      expect(subject).to respond_to(:issn)
      expect(subject).to respond_to(:note)
      expect(subject).to respond_to(:place_of_publication)
      expect(subject).to respond_to(:series)
      expect(subject).to respond_to(:language_label)
      expect(subject).to respond_to(:license_label)
      expect(subject).to respond_to(:rights_statement_label)
    end
  end

  describe 'DOI normalization' do
    it 'normalizes bare DOI to canonical format on save' do
      subject.title = ['Test Article']
      subject.doi = '10.1234/test'
      subject.save!

      expect(subject.doi).to eq('https://doi.org/10.1234/test')
    end

    it 'normalizes dx.doi.org to doi.org on save' do
      subject.title = ['Test Article']
      subject.doi = 'https://dx.doi.org/10.1234/test'
      subject.save!

      expect(subject.doi).to eq('https://doi.org/10.1234/test')
    end

    it 'leaves already canonical DOI unchanged' do
      subject.title = ['Test Article']
      subject.doi = 'https://doi.org/10.1234/test'
      subject.save!

      expect(subject.doi).to eq('https://doi.org/10.1234/test')
    end

    it 'sets invalid DOI to nil and logs warning' do
      subject.title = ['Test Article']
      subject.doi = 'not-a-doi'

      allow(Rails.logger).to receive(:warn)
      subject.save!

      expect(subject.doi).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Invalid DOI format 'not-a-doi'.*setting to nil/)
    end

    it 'sets empty string DOI to nil without logging' do
      subject.title = ['Test Article']
      subject.doi = ''

      allow(Rails.logger).to receive(:warn)
      subject.save!

      expect(subject.doi).to be_nil
      expect(Rails.logger).not_to have_received(:warn)
    end
  end
end
