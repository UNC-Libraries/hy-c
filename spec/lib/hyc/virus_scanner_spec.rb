require 'rails_helper'
require 'fileutils'
require 'tempfile'
require 'pathname'

RSpec.describe Hyc::VirusScanner do
  subject(:scanner) { described_class.new(file) }
  let(:file) { Tempfile.new.path }

  context 'when a file is not infected' do
    before do
      src_path = Pathname.new('spec/fixtures/files/test.txt').realpath.to_s
      FileUtils.rm(file)
      FileUtils.cp(src_path, file)
    end

    it 'does not have a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::SuccessResponse
    end

    it 'does not have a virus normal hyrax scan' do
      expect(scanner).not_to be_infected
    end
  end

  context 'when a file is infected' do
    before do
      src_path = Pathname.new('spec/fixtures/files/virus.txt').realpath.to_s
      FileUtils.rm(file)
      FileUtils.cp(src_path, file)
    end

    it 'has a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::VirusResponse
    end

    it 'has a virus hy-c normal hyrax scan' do
      expect(scanner).to be_infected
    end
  end
end
