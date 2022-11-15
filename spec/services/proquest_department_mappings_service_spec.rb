# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::ProquestDepartmentMappingsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#standard_department_name' do
    it 'returns department name mapped to proquest department' do
      expect(service.standard_department_name('Biology')).to eq ['Department of Biology']
    end

    it 'returns nil for unmapped proquest department' do
      expect { service.standard_department_name('American History') }.to raise_error(ProquestDepartmentMappingsService::UnknownDepartmentError)
    end
  end
end
