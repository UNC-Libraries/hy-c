require 'rails_helper'

RSpec.describe Hyrax::HonorsConcentrationService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns only active terms" do
      expect(service.select_all_options).to include(['Anthropology', 'Anthropology'],
                                                    ['Chemistry', 'Chemistry'],
                                                    ['Biostatistics', 'Biostatistics'],
                                                    ['Applied Science', 'Applied Science'],
                                                    ['Business Administration', 'Business Administration'],
                                                    ['Communication Studies', 'Communication Studies'],
                                                    ['Comparative Literature', 'Comparative Literature'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('Biostatistics')).to eq('Biostatistics')
    end
  end
end