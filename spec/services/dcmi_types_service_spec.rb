# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DcmiTypeService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['Dataset', 'http://purl.org/dc/dcmitype/Dataset'],
                                                    ['Sound', 'http://purl.org/dc/dcmitype/Sound'],
                                                    ['Still Image', 'http://purl.org/dc/dcmitype/StillImage'],
                                                    ['Text', 'http://purl.org/dc/dcmitype/Text'])
    end
  end

  describe '#label' do
    it 'resolves for ids of terms' do
      expect(service.label('http://purl.org/dc/dcmitype/Text')).to eq('Text')
    end
  end
end
