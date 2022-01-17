require 'rails_helper'

RSpec.describe Hyrax::MimeTypeService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['mp4', 'video/mp4'],
                                                    ['xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
                                                    ['txt', 'text/plain'])
    end
  end

  describe '#label' do
    it 'resolves for ids of terms' do
      expect(service.label('application/x-compressed')).to eq('tgz')
    end
  end

  describe '#valid?' do
    it 'detects if term is present in authority' do
      expect(service.valid?('something')).to be_nil
      expect(service.valid?('txt')).to eq({ 'id' => 'text/plain', 'label' => 'txt', 'active' => true })
    end
  end
end
