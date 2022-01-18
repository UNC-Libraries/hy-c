require 'rails_helper'

RSpec.describe Hyrax::BiomedDepartmentMappingsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#standard_department_name' do
    it 'returns department name mapped to biomed address' do
      expect(service.standard_department_name(['Biomedical Research Imaging Center, University of North Carolina at Chapel Hill']))
        .to eq ['School of Medicine, Biomedical Research Imaging Center']
    end

    it 'returns a compacted and flattened array of departments' do
      expect(service.standard_department_name(['Biomedical Research Imaging Center, University of North Carolina at Chapel Hill',
                                               'some other address',
                                               'Biostatistics, Lineberger Comprehensive Cancer Center, University of North Carolina, Chapel Hill, NC, 27599-7295, USA']))
        .to eq ['School of Medicine, Biomedical Research Imaging Center', 'Gillings School of Global Public Health, Department of Biostatistics', 'UNC Lineberger Comprehensive Cancer Center']
    end

    it 'returns nil for unmapped biomed address' do
      expect(service.standard_department_name(['Wilson Library'])).to eq []
    end
  end
end
