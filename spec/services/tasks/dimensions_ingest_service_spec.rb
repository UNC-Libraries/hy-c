# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsIngestService do
  let(:dimensions_ingest_test_fixture) do
    File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
  end

  # Retrieving fixture publications and randomly assigning the marked_for_review attribute
  let(:test_input) do
    fixture_publications = JSON.parse(dimensions_ingest_test_fixture)['publications']
    fixture_publications.each do |publication|
      random_number = rand(1..5)
      if random_number == 1
        publication['marked_for_review'] = true
  end
    end
    fixture_publications
  end

  describe '#ingest_dimensions_publications' do
    it 'ingests the publications into the database' do
      described_class.new.ingest_publications(test_input)
    #   expect { described_class.new.ingest_dimensions_publications(publications) }
    #     .to change { Publication.count }.by(2)
    end
  end
end
