require 'rails_helper'

RSpec.describe Hyrax::DegreesService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns all terms" do
      expect(service.select_all_options).to include(
                                                ['Master of Science in Information Science', 'Master of Science in Information Science'],
                                                ['Master of Science in Library Science', 'Master of Science in Library Science'],
                                                ['Master of Science in Information Science', 'MSIS'])
    end
  end

  describe "#select_active_options" do
    it "returns all active terms" do
      expect(service.select_active_options).to include(
                                                ['Master of Science in Information Science', 'Master of Science in Information Science'],
                                                ['Master of Science in Library Science', 'Master of Science in Library Science'])
    end

    it "does not return inactive terms" do
      expect(service.select_active_options).not_to include(['Master of Science in Information Science', 'MSIS'])
    end
  end

  describe "#label" do
    it "resolves for ids of active terms" do
      expect(service.label('Master of Science in Information Science')).to eq("Master of Science in Information Science")
    end

    it "resolves for ids of inactive terms" do
      expect(service.label('MSIS')).to eq("Master of Science in Information Science")
    end
  end
end

