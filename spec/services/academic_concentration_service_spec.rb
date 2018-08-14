require 'rails_helper'

RSpec.describe Hyrax::AcademicConcentrationService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns only active terms" do
      expect(service.select_all_options).to include(['Aquatic and Atmospheric Sciences', 'Aquatic and Atmospheric Sciences'],
                                                    ['Clinical Nutrition', 'Clinical Nutrition'],
                                                    ['Economic Development', 'Economic Development'],
                                                    ['Environmental Chemistry and Biology', 'Environmental Chemistry and Biology'],
                                                    ['Environmental Engineering', 'Environmental Engineering'],
                                                    ['Environmental Health Sciences', 'Environmental Health Sciences'],
                                                    ['Environmental Management and Policy', 'Environmental Management and Policy'],
                                                    ['Housing and Community Development', 'Housing and Community Development'],
                                                    ['Industrial Hygiene', 'Industrial Hygiene'],
                                                    ['Land Use and Environmental Planning', 'Land Use and Environmental Planning'],
                                                    ['Public Health Nutrition', 'Public Health Nutrition'],
                                                    ['Sustainable Water Resources', 'Sustainable Water Resources'],
                                                    ['Transportation Planning', 'Transportation Planning'],
                                                    ['Water Resources Engineering', 'Water Resources Engineering'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('Economic Development')).to eq('Economic Development')
    end
  end
end