# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'

RSpec.describe DataSet do
  it "has a title" do
    subject.title = ['data set']
    expect(subject.title).to eq ['data set']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_data_set' }
  end

  describe "metadata" do
    it "has metadata" do
      expect(subject).to respond_to(:relative_path)
      expect(subject).to respond_to(:depositor)
      expect(subject).to respond_to(:contributor)
      expect(subject).to respond_to(:creator)
      expect(subject).to respond_to(:title)
      expect(subject).to respond_to(:label)
      expect(subject).to respond_to(:keyword)
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

      # Custom fields
      expect(subject).to respond_to(:abstract)
      expect(subject).to respond_to(:access)
      expect(subject).to respond_to(:affiliation)
      expect(subject).to respond_to(:copyright_date)
      expect(subject).to respond_to(:date_issued)
      expect(subject).to respond_to(:doi)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:funder)
      expect(subject).to respond_to(:genre)
      expect(subject).to respond_to(:geographic_subject)
      expect(subject).to respond_to(:last_date_modified)
      expect(subject).to respond_to(:orcid)
      expect(subject).to respond_to(:other_affiliation)
      expect(subject).to respond_to(:project_director)
      expect(subject).to respond_to(:researcher)
      expect(subject).to respond_to(:rights_holder)
      expect(subject).to respond_to(:sponsor)
      expect(subject).to respond_to(:use)
    end
  end
end