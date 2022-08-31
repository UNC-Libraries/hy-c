# frozen_string_literal: true
require 'rails_helper'
require 'fileutils'
require 'tempfile'
require 'pathname'

# Check for github actions runner when setting file path
# Github actions needs a different path than the local vm
RSpec.describe Hyc::VirusScanner do
  context 'with an environment variable set' do
    around do |example|
      cached_clamav_host = ENV['CLAMD_TCP_HOST']
      ENV['CLAMD_TCP_HOST'] = 'clamav'
      example.run
      ENV['CLAMD_TCP_HOST'] = cached_clamav_host
    end

    it 'knows the ClamAV host' do
      expect(described_class.clamav_host).to eq('clamav')
    end
  end

  context 'with the environment variable unset' do
    around do |example|
      cached_clamav_host = ENV['CLAMD_TCP_HOST']
      ENV.delete('CLAMD_TCP_HOST')
      example.run
      ENV['CLAMD_TCP_HOST'] = cached_clamav_host
    end

    it 'defaults to localhost' do
      expect(described_class.clamav_host).to eq('localhost')
    end
  end

  context 'when a file is not infected' do
    subject(:scanner) { described_class.new(file) }

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
    subject(:scanner) { described_class.new(file) }

    let(:file) { 'not/a/file.txt' }

    it 'raises an error' do
      expect { scanner.infected? }.to raise_error(ClamAV::Util::UnknownPathException)
    end
  end

  context 'when a file is infected' do
    subject(:scanner) { described_class.new(file) }

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
    subject(:scanner) { described_class.new(file) }

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
