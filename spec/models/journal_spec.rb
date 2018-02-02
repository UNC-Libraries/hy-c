# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Journal do
  it "has a title" do
    subject.title = ['journal']
    expect(subject.title).to eq ['journal']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_journal' }
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
      expect(subject).to respond_to(:alternate_title)
      expect(subject).to respond_to(:conference_name)
      expect(subject).to respond_to(:date_issued)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:genre)
      expect(subject).to respond_to(:geographic_subject)
      expect(subject).to respond_to(:issn)
      expect(subject).to respond_to(:note)
      expect(subject).to respond_to(:place_of_publication)
      expect(subject).to respond_to(:table_of_contents)
    end
  end
end
