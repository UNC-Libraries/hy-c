require 'rails_helper'

RSpec.describe Hyc::VirusScanner do
  subject(:scanner) { described_class.new(file) }

  context 'when a file is not infected' do
    let(:file) { Dir.pwd + '/spec/fixtures/files/test.txt' }

    it 'does not have a virus' do
      expect(scanner.infected?).to be_a ClamAV::SuccessResponse
    end
  end

  context 'when a file is infected' do
    let(:file) { Dir.pwd + '/spec/fixtures/files/virus.txt' }

    it 'has a virus' do
      expect(scanner.infected?).to be_a ClamAV::VirusResponse
    end
  end
end
