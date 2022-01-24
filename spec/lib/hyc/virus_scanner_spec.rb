require 'rails_helper'
require 'fileutils'
require 'tempfile'
require 'pathname'

# Check for github actions runner when setting file path
# Github actions needs a different path than the local vm
RSpec.describe Hyc::VirusScanner do
  subject(:scanner) { described_class.new(file) }

  context 'when a file is not infected' do
    src_path = Pathname.new('spec/fixtures/files/test.txt').realpath.to_s

    if Dir.pwd.include? 'runner'
      let(:file) { Tempfile.new.path }
    else
      let(:file) { src_path }
    end

    before do
      if Dir.pwd.include? 'runner'
        FileUtils.rm(file)
        FileUtils.cp(src_path, file)
      end
    end

    it 'does not have a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::SuccessResponse
    end

    it 'does not have a virus normal hyrax scan' do
      expect(scanner).not_to be_infected
    end
  end

  context 'when it cannot find the file' do
    let(:file) { 'not/a/file.txt' }

    it 'raises an error' do
      expect { scanner.infected? }.to raise_error(ClamAV::Util::UnknownPathException)
    end
  end

  context 'when a file is infected' do
    src_path = Pathname.new('spec/fixtures/files/virus.txt').realpath.to_s
    if Dir.pwd.include? 'runner'
      let(:file) { Tempfile.new.path }
    else
      let(:file) { src_path }
    end

    before do
      if Dir.pwd.include? 'runner'
        FileUtils.rm(file)
        FileUtils.cp(src_path, file)
      end
    end

    it 'has a virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::VirusResponse
    end

    it 'has a virus hy-c normal hyrax scan' do
      expect(scanner).to be_infected
    end
  end

  context 'when a file name has special characters' do
    src_path = Pathname.new('spec/fixtures/files/odd_chars_+.txt').realpath.to_s

    if Dir.pwd.include? 'runner'
      let(:file) { Tempfile.new.path }
    else
      let(:file) { src_path }
    end

    before do
      if Dir.pwd.include? 'runner'
        FileUtils.rm(file)
        FileUtils.cp(src_path, file)
      end
    end

    it 'can perform a custom virus hy-c custom scan' do
      expect(scanner.hyc_infected?).to be_a ClamAV::SuccessResponse
    end

    it 'does not have a virus normal hyrax scan' do
      expect(scanner).not_to be_infected
    end
  end
end
