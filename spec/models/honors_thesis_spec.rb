# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'

RSpec.describe HonorsThesis do

  it 'has a title' do
    subject.title = ['foo']
    expect(subject.title).to eq ['foo']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_honors_thesis' }
  end

  describe "metadata" do
    it "has descriptive metadata" do
      # Basic hyrax metadata
      expect(subject).to respond_to(:relative_path)
      expect(subject).to respond_to(:depositor)
      expect(subject).to respond_to(:related_url)
      expect(subject).to respond_to(:based_near)
      expect(subject).to respond_to(:contributor)
      expect(subject).to respond_to(:creator)
      expect(subject).to respond_to(:title)
      expect(subject).to respond_to(:label)
      expect(subject).to respond_to(:keyword)
      expect(subject).to respond_to(:description)
      expect(subject).to respond_to(:publisher)
      expect(subject).to respond_to(:date_created)
      expect(subject).to respond_to(:date_uploaded)
      expect(subject).to respond_to(:date_modified)
      expect(subject).to respond_to(:subject)
      expect(subject).to respond_to(:language)
      expect(subject).to respond_to(:license)
      expect(subject).to respond_to(:rights_statement)
      expect(subject).to respond_to(:identifier)
      expect(subject).to respond_to(:source)
      expect(subject).to respond_to(:resource_type)
      expect(subject).to respond_to(:deposit_record)

      # Additional metadata
      expect(subject).to respond_to(:abstract)
      expect(subject).to respond_to(:academic_concentration)
      expect(subject).to respond_to(:access)
      expect(subject).to respond_to(:advisor)
      expect(subject).to respond_to(:affiliation)
      expect(subject).to respond_to(:alternative_title)
      expect(subject).to respond_to(:award)
      expect(subject).to respond_to(:date_issued)
      expect(subject).to respond_to(:degree)
      expect(subject).to respond_to(:degree_granting_institution)
      expect(subject).to respond_to(:doi)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:dcmi_type)
      expect(subject).to respond_to(:geographic_subject)
      expect(subject).to respond_to(:graduation_year)
      expect(subject).to respond_to(:note)
      expect(subject).to respond_to(:use)
    end
  end
end
