# Generated via
#  `rails generate hyrax:work Artwork`
require 'rails_helper'

RSpec.describe Artwork do
  it 'has a title' do
    subject.title = ['foo']
    expect(subject.title).to eq ['foo']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_art_work' }
  end

  describe "metadata" do
    it "has descriptive metadata" do
      # Basic hyrax metadata
      expect(subject).to respond_to(:relative_path)
      expect(subject).to respond_to(:title)
      expect(subject).to respond_to(:label)
      expect(subject).to respond_to(:description)
      expect(subject).to respond_to(:publisher)
      expect(subject).to respond_to(:date_created)
      expect(subject).to respond_to(:date_uploaded)
      expect(subject).to respond_to(:date_modified)
      expect(subject).to respond_to(:license)
      expect(subject).to respond_to(:rights_statement)
      expect(subject).to respond_to(:resource_type)

      # Additional metadata
      expect(subject).to respond_to(:doi)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:medium)
      expect(subject).to respond_to(:license_label)
      expect(subject).to respond_to(:rights_statement_label)
    end
  end
end
