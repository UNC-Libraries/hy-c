require 'rails_helper'

RSpec.describe Hyc::VirusScanner do
  subject(:scanner) { described_class.new(file) }

  context 'when a file is not infected' do
    let(:file) { "#{Dir.pwd}/spec/fixtures/files/test.txt" }

    it 'does not have a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::SuccessResponse
    end

    it 'does not have a virus normal hyrax scan' do
      expect(scanner).not_to be_infected
    end
  end

  context 'when a file is infected' do
    let(:file) { "#{Dir.pwd}/spec/fixtures/files/virus.txt" }

    it 'has a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::VirusResponse
    end

    it 'has a virus hy-c normal hyrax scan' do
      expect(scanner).to be_infected
    end
  end
end
