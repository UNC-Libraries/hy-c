require 'rails_helper'

RSpec.describe Hyrax::KindOfDataService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe "#select_all_options" do
    it "returns all terms" do
      expect(service.select_all_options).to include(['Numeric', 'Numeric'], ['Text', 'Text'],
                                                    ['Still Image', 'Still Image'], ['Geospatial', 'Geospatial'],
                                                    ['Audio', 'Audio'], ['Video', 'Video'],
                                                    ['Software', 'Software'],
                                                    ['Interactive Resource', 'Interactive Resource'],
                                                    ['3D', '3D'], ['Other', 'Other'])
    end
  end

  describe "#label" do
    it "resolves for ids of terms" do
      expect(service.label('Numeric')).to eq('Numeric')
    end
  end
end