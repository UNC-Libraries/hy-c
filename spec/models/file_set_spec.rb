# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FileSet do
  describe '#to_solr' do
    it 'indexes alt_text as stored searchable metadata' do
      file_set = described_class.new(alt_text: 'Descriptive image alt text')

      expect(file_set.to_solr['alt_text_tesim']).to include('Descriptive image alt text')
    end
  end

  describe 'after destroy' do
    let(:checksum_value) { '12345checksum' }
    let(:checksum) { double('checksum', value: checksum_value) }
    let(:original_file) { instance_double(Hydra::PCDM::File, checksum: checksum, mime_type: 'application/octet-stream') }

    before do
      allow(subject).to receive(:original_file).and_return(original_file)
      allow(DeregisterLongleafJob).to receive(:perform_later).with(checksum_value)
    end

    it 'calls longleaf deregister hook' do
      subject.destroy

      expect(DeregisterLongleafJob).to have_received(:perform_later).with(checksum_value)
    end
  end
end
