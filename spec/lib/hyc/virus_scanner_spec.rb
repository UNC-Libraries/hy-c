require 'rails_helper'

RSpec.describe Hyc::VirusScanner do
  subject(:scanner) { described_class.new(file) }

  context 'when a file is not infected' do
    test_file_path = Pathname.new('spec/fixtures/files/test.txt').realpath.to_s
    let(:file) { test_file_path }

    it 'does not have a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::SuccessResponse
    end

    it 'does not have a virus normal hyrax scan' do
      expect(scanner).not_to be_infected
    end
  end

  context 'when a file is infected' do
    test_file_path = Pathname.new('spec/fixtures/files/virus.txt').realpath.to_s
    let(:file) { test_file_path }

    it 'has a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::VirusResponse
    end

    it 'has a virus hy-c normal hyrax scan' do
      expect(scanner).to be_infected
    end
  end
end
