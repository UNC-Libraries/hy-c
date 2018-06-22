require 'rails_helper'

RSpec.describe Hyrax::CdrLicenseService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe "#select_options" do
    it "returns all options for non dataSet work types" do
      expect(service.select('hyrax/masters_papers')).to include(
                                              ['Attribution 3.0 United States', 'http://creativecommons.org/licenses/by/3.0/us/'],
                                              ['Attribution-ShareAlike 3.0 United States', 'http://creativecommons.org/licenses/by-sa/3.0/us/'],
                                              ['Attribution-NonCommercial 3.0 United States', 'http://creativecommons.org/licenses/by-nc/3.0/us/'])
    end

    it "returns 'limited' options for dataSet work type" do
      expect(service.select('hyrax/masters_papers')).to include(['Attribution 3.0 United States', 'http://creativecommons.org/licenses/by/3.0/us/'])
    end

    it "returns a 'selected' option value of 'CC license' for dataSet work types" do
      expect(service.default_license('hyrax/data_sets')).to eq('http://creativecommons.org/publicdomain/zero/1.0/')
    end

    it "returns a 'selected' option value of '' for non dataSet work types" do
      expect(service.default_license('hyrax/masters_papers')).to eq('')
    end
  end
end