require 'rails_helper'

RSpec.describe Hyrax::AcademicConcentrationService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#select_options' do
    it 'returns only active  masters papers terms for masters form' do
      expect(service.select('masters')).to include(['Aquatic and Atmospheric Sciences', 'Aquatic and Atmospheric Sciences'],
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

    it 'returns only honors thesis active terms for honors form' do
      expect(service.select('honors')).to include(['Anthropology', 'Anthropology'],
                                                  ['Chemistry', 'Chemistry'],
                                                  ['Biostatistics', 'Biostatistics'],
                                                  ['Applied Science', 'Applied Science'],
                                                  ['Business Administration', 'Business Administration'],
                                                  ['Communication Studies', 'Communication Studies'],
                                                  ['Comparative Literature', 'Comparative Literature'])
    end

    it 'returns all terms for general form' do
      expect(service.select('all')).to include(['Aquatic and Atmospheric Sciences', 'Aquatic and Atmospheric Sciences'],
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
                                               ['Water Resources Engineering', 'Water Resources Engineering'],
                                               ['Anthropology', 'Anthropology'],
                                               ['Chemistry', 'Chemistry'],
                                               ['Biostatistics', 'Biostatistics'],
                                               ['Applied Science', 'Applied Science'],
                                               ['Business Administration', 'Business Administration'],
                                               ['Communication Studies', 'Communication Studies'],
                                               ['Comparative Literature', 'Comparative Literature'])
    end
  end

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('Economic Development')).to eq('Economic Development')
    end
  end
end
