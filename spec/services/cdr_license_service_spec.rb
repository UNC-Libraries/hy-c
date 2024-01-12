require 'rails_helper'

RSpec.describe Hyrax::CdrLicenseService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#select_options' do
    context 'as an admin' do
      it 'returns all options for non dataSet work types' do
        expect(service.select('hyrax/masters_papers', true)).to contain_exactly(
          ['Attribution 4.0 International', 'http://creativecommons.org/licenses/by/4.0/'],
          ['Attribution-NonCommercial 4.0 International', 'http://creativecommons.org/licenses/by-nc/4.0/'],
          ['Attribution-NoDerivs 4.0 International', 'http://creativecommons.org/licenses/by-nd/4.0/'],
          ['Attribution-ShareAlike 4.0 International', 'https://creativecommons.org/licenses/by-sa/4.0/'],
          ['Attribution-NonCommercial-ShareAlike 4.0 International', 'https://creativecommons.org/licenses/by-nc-sa/4.0/'],
          ['Attribution-NonCommercial-NoDerivs 4.0 International', 'https://creativecommons.org/licenses/by-nc-nd/4.0/'],
          ['Attribution 3.0 United States', 'http://creativecommons.org/licenses/by/3.0/us/'],
          ['Attribution-ShareAlike 3.0 United States', 'http://creativecommons.org/licenses/by-sa/3.0/us/'],
          ['Attribution-NonCommercial 3.0 United States', 'http://creativecommons.org/licenses/by-nc/3.0/us/'],
          ['Attribution-NoDerivs 3.0 United States', 'http://creativecommons.org/licenses/by-nd/3.0/us/'],
          ['Attribution-NonCommercial-NoDerivs 3.0 United States', 'http://creativecommons.org/licenses/by-nc-nd/3.0/us/'],
          ['Attribution-NonCommercial-ShareAlike 3.0 United States', 'http://creativecommons.org/licenses/by-nc-sa/3.0/us/'],
          ['Public Domain Mark 1.0', 'http://creativecommons.org/publicdomain/mark/1.0/'],
          ['CC0 1.0 Universal', 'http://creativecommons.org/publicdomain/zero/1.0/'],
          ['All rights reserved', 'http://www.europeana.eu/portal/rights/rr-r.html'])
      end

      it "returns 'limited' options for dataSet work type" do
        expect(service.select('hyrax/data_sets', true)).to contain_exactly(
          ['Attribution 4.0 International', 'http://creativecommons.org/licenses/by/4.0/'],
          ['Attribution 3.0 United States', 'http://creativecommons.org/licenses/by/3.0/us/'],
          ['CC0 1.0 Universal', 'http://creativecommons.org/publicdomain/zero/1.0/'])
      end
    end

    context 'as a non-admin' do
      it 'returns all non-archived options for non dataSet work types' do
        expect(service.select('hyrax/masters_papers', false)).to contain_exactly(
          ['Attribution 4.0 International', 'http://creativecommons.org/licenses/by/4.0/'],
          ['Attribution-NonCommercial 4.0 International', 'http://creativecommons.org/licenses/by-nc/4.0/'],
          ['Attribution-NoDerivs 4.0 International', 'http://creativecommons.org/licenses/by-nd/4.0/'],
          ['Attribution-ShareAlike 4.0 International', 'https://creativecommons.org/licenses/by-sa/4.0/'],
          ['Attribution-NonCommercial-ShareAlike 4.0 International', 'https://creativecommons.org/licenses/by-nc-sa/4.0/'],
          ['Attribution-NonCommercial-NoDerivs 4.0 International', 'https://creativecommons.org/licenses/by-nc-nd/4.0/'],
          ['Public Domain Mark 1.0', 'http://creativecommons.org/publicdomain/mark/1.0/'],
          ['CC0 1.0 Universal', 'http://creativecommons.org/publicdomain/zero/1.0/'],
          ['All rights reserved', 'http://www.europeana.eu/portal/rights/rr-r.html'])
      end

      it "returns 'limited' non-archived options for dataSet work type" do
        expect(service.select('hyrax/data_sets', false)).to contain_exactly(
          ['Attribution 4.0 International', 'http://creativecommons.org/licenses/by/4.0/'],
          ['CC0 1.0 Universal', 'http://creativecommons.org/publicdomain/zero/1.0/'])
      end
    end

    it "returns a 'selected' option value of 'CC license' for dataSet work types" do
      expect(service.default_license('hyrax/data_sets')).to eq('http://creativecommons.org/publicdomain/zero/1.0/')
    end

    it "returns a 'selected' option value of '' for non dataSet work types" do
      expect(service.default_license('hyrax/masters_papers')).to eq('')
    end
  end

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('http://creativecommons.org/licenses/by-sa/3.0/us/')).to eq('Attribution-ShareAlike 3.0 United States')
    end

    it 'resolves to the same label for http or https ids' do
      expect(service.label('https://creativecommons.org/licenses/by-sa/3.0/us/')).to eq('Attribution-ShareAlike 3.0 United States')
    end
  end
end
