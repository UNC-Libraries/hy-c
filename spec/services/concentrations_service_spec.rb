require 'rails_helper'

RSpec.describe Hyrax::ConcentrationsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns only active terms" do
      expect(service.select_all_options).to include(['Cell Biology', 'cell_biology'],
                                                    ['Organic Chemistry', 'organic_chemistry'],
                                                    ['American History', 'american_history'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('american_history')).to eq('American History')
    end

    it "resolves for ids of inactive terms" do
      expect(service.label('old_concentration')).to eq('Old Concentration')
    end
  end
end

