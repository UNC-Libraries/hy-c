# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

RSpec.describe MastersPaper do
  it 'has a title' do
    subject.title = ['foo']
    expect(subject.title).to eq ['foo']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_masters_paper' }
  end

  describe 'metadata' do
    it 'has descriptive metadata' do
      # Basic hyrax metadata
      expect(subject).to respond_to(:relative_path)
      expect(subject).to respond_to(:depositor)
      expect(subject).to respond_to(:creator)
      expect(subject).to respond_to(:creators)
      expect(subject).to respond_to(:title)
      expect(subject).to respond_to(:label)
      expect(subject).to respond_to(:keyword)
      expect(subject).to respond_to(:date_created)
      expect(subject).to respond_to(:date_uploaded)
      expect(subject).to respond_to(:date_modified)
      expect(subject).to respond_to(:based_near)
      expect(subject).to respond_to(:subject)
      expect(subject).to respond_to(:language)
      expect(subject).to respond_to(:license)
      expect(subject).to respond_to(:rights_statement)
      expect(subject).to respond_to(:resource_type)
      expect(subject).to respond_to(:access_right)
      expect(subject).to respond_to(:rights_notes)

      # Additional metadata
      expect(subject).to respond_to(:abstract)
      expect(subject).to respond_to(:academic_concentration)
      expect(subject).to respond_to(:admin_note)
      expect(subject).to respond_to(:advisors)
      expect(subject).to respond_to(:date_issued)
      expect(subject).to respond_to(:degree)
      expect(subject).to respond_to(:degree_granting_institution)
      expect(subject).to respond_to(:deposit_agreement)
      expect(subject).to respond_to(:deposit_record)
      expect(subject).to respond_to(:doi)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:dcmi_type)
      expect(subject).to respond_to(:graduation_year)
      expect(subject).to respond_to(:note)
      expect(subject).to respond_to(:reviewers)
      expect(subject).to respond_to(:language_label)
      expect(subject).to respond_to(:license_label)
      expect(subject).to respond_to(:rights_statement_label)
    end
  end
end
