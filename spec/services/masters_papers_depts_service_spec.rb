require 'rails_helper'

RSpec.describe Hyrax::MastersPapersDeptsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns only active terms" do
      expect(service.select_all_options).to include(['Department of City and Regional Planning', 'Department of City and Regional Planning'],
                                                    ['Studio Art Program', 'Studio Art Program'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('Studio Art Program')).to eq('College of Arts and Sciences; Department of Art; Studio Art Program')
    end
  end

  describe "#identifier" do
    it "resolves for labels of active terms" do
      expect(service.identifier('College of Arts and Sciences; Department of City and Regional Planning')).to eq('Department of City and Regional Planning')
    end
  end
end
