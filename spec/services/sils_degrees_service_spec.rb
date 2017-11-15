require 'rails_helper'

RSpec.describe Hyrax::SilsDegreesService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns all terms" do
      expect(service.select_all_options).to include(['MSIS', 'msis'], ['MSLS', 'msls'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('msis')).to eq("MSIS")
    end
  end
end

