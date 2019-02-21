# Generated via
#  `rails generate hyrax:work General`
require 'rails_helper'

RSpec.describe General do
  it 'has a title' do
    subject.title = ['foo']
    expect(subject.title).to eq ['foo']
  end

  describe '.model_name' do
    subject { described_class.model_name.singular_route_key }

    it { is_expected.to eq 'hyrax_general' }
  end

  describe "metadata" do
    it "has descriptive metadata" do
      # Basic hyrax metadata
      expect(subject).to respond_to(:relative_path)
      expect(subject).to respond_to(:depositor)
      expect(subject).to respond_to(:related_url)
      expect(subject).to respond_to(:based_near)
      expect(subject).to respond_to(:contributor)
      expect(subject).to respond_to(:contributors)
      expect(subject).to respond_to(:creator)
      expect(subject).to respond_to(:creators)
      expect(subject).to respond_to(:title)
      expect(subject).to respond_to(:label)
      expect(subject).to respond_to(:keyword)
      expect(subject).to respond_to(:description)
      expect(subject).to respond_to(:publisher)
      expect(subject).to respond_to(:date_created)
      expect(subject).to respond_to(:date_uploaded)
      expect(subject).to respond_to(:date_modified)
      expect(subject).to respond_to(:based_near)
      expect(subject).to respond_to(:subject)
      expect(subject).to respond_to(:language)
      expect(subject).to respond_to(:license)
      expect(subject).to respond_to(:rights_statement)
      expect(subject).to respond_to(:bibliographic_citation)
      expect(subject).to respond_to(:identifier)
      expect(subject).to respond_to(:source)
      expect(subject).to respond_to(:resource_type)

      # Additional metadata
      expect(subject).to respond_to(:abstract)
      expect(subject).to respond_to(:academic_concentration)
      expect(subject).to respond_to(:access)
      expect(subject).to respond_to(:advisors)
      expect(subject).to respond_to(:alternative_title)
      expect(subject).to respond_to(:arrangers)
      expect(subject).to respond_to(:award)
      expect(subject).to respond_to(:composers)
      expect(subject).to respond_to(:conference_name)
      expect(subject).to respond_to(:copyright_date)
      expect(subject).to respond_to(:date_issued)
      expect(subject).to respond_to(:date_other)
      expect(subject).to respond_to(:degree)
      expect(subject).to respond_to(:degree_granting_institution)
      expect(subject).to respond_to(:deposit_record)
      expect(subject).to respond_to(:digital_collection)
      expect(subject).to respond_to(:doi)
      expect(subject).to respond_to(:edition)
      expect(subject).to respond_to(:extent)
      expect(subject).to respond_to(:funder)
      expect(subject).to respond_to(:dcmi_type)
      expect(subject).to respond_to(:graduation_year)
      expect(subject).to respond_to(:isbn)
      expect(subject).to respond_to(:issn)
      expect(subject).to respond_to(:journal_issue)
      expect(subject).to respond_to(:journal_title)
      expect(subject).to respond_to(:journal_volume)
      expect(subject).to respond_to(:kind_of_data)
      expect(subject).to respond_to(:last_modified_date)
      expect(subject).to respond_to(:medium)
      expect(subject).to respond_to(:methodology)
      expect(subject).to respond_to(:note)
      expect(subject).to respond_to(:page_end)
      expect(subject).to respond_to(:page_start)
      expect(subject).to respond_to(:peer_review_status)
      expect(subject).to respond_to(:place_of_publication)
      expect(subject).to respond_to(:project_directors)
      expect(subject).to respond_to(:publisher_version)
      expect(subject).to respond_to(:researchers)
      expect(subject).to respond_to(:reviewers)
      expect(subject).to respond_to(:rights_holder)
      expect(subject).to respond_to(:series)
      expect(subject).to respond_to(:sponsor)
      expect(subject).to respond_to(:table_of_contents)
      expect(subject).to respond_to(:translators)
      expect(subject).to respond_to(:use)
      expect(subject).to respond_to(:language_label)
      expect(subject).to respond_to(:license_label)
      expect(subject).to respond_to(:rights_statement_label)
    end
  end
end
