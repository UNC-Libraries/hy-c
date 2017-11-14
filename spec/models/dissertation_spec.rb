# Generated via
#  `rails generate hyrax:work Dissertation`
require 'rails_helper'

RSpec.describe Dissertation do
  # TODO: write tests for 'dissertation' work type
  # need to verify that the work type accepts all expected properties
  # include the workflow here?
  # check that single-valued fields only have one value (title) <= do in form tests

  it 'has a title' do
    subject.title = ['foo']
    expect(subject.title).to eq ['foo']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_dissertation' }
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

      # Additional metadata
      expect(subject).to respond_to(:author_degree_granted)
      expect(subject).to respond_to(:author_academic_concentration)
      expect(subject).to respond_to(:institution)
      expect(subject).to respond_to(:author_graduation_date)
      expect(subject).to respond_to(:date_published)
      expect(subject).to respond_to(:faculty_advisor_name)
    end
  end
end
