# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestStatusService, :ingest do
  let(:tmp_dir) { Dir.mktmpdir }
  subject { Tasks::IngestStatusService.new(File.join(tmp_dir, 'deposit_status.json')) }

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe '#initialize_statuses' do
    let(:package_paths) { Dir.glob('spec/fixtures/proquest/*.zip').sort }

    it 'initializes and stores an outcome mapping' do
      subject.initialize_statuses(package_paths)

      # make sure the statuses persisted
      statuses = subject.load_statuses
      expect(statuses.size).to eq 2
      package1 = statuses['proquest-attach0.zip']
      expect(package1['status']).to eq 'Pending'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to be_nil
      package1 = statuses['proquest-attach7.zip']
      expect(package1['status']).to eq 'Pending'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to be_nil
    end
  end

  describe '#status_complete' do
    it 'adds a complete status' do
      subject.status_complete('test_file.zip')

      # make sure the statuses persisted
      statuses = subject.statuses
      expect(statuses.size).to eq 1
      package1 = statuses['test_file.zip']
      expect(package1['status']).to eq 'Complete'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to be_nil
    end
  end

  describe '#status_in_progress' do
    it 'adds a in progress status' do
      subject.status_in_progress('test_file.zip')

      # make sure the statuses persisted
      statuses = subject.statuses
      expect(statuses.size).to eq 1
      package1 = statuses['test_file.zip']
      expect(package1['status']).to eq 'In Progress'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error']).to be_nil
    end

    it 'adds multiple errors' do
      subject.status_in_progress('test_file.zip', error: StandardError.new('Error Number One'))
      subject.status_in_progress('test_file.zip', error: StandardError.new('Second Error'))

      # make sure the statuses persisted
      statuses = subject.statuses
      expect(statuses.size).to eq 1
      package1 = statuses['test_file.zip']
      expect(package1['status']).to eq 'In Progress'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error'].length).to eq 2
      expect(package1['error'][0]['message']).to eq 'Error Number One'
      expect(package1['error'][0]['trace']).to be_nil
      expect(package1['error'][1]['message']).to eq 'Second Error'
      expect(package1['error'][1]['trace']).to be_nil
    end
  end

  describe '#status_failed' do
    it 'adds a failed status with error' do
      error = StandardError.new('Oh no')
      error.set_backtrace(caller)
      subject.status_failed('test_file.zip', error)

      # make sure the statuses persisted
      statuses = subject.statuses
      expect(statuses.size).to eq 1
      package1 = statuses['test_file.zip']
      expect(package1['status']).to eq 'Failed'
      expect(package1['status_timestamp']).to_not be_nil
      expect(package1['error'][0]['message']).to eq 'Oh no'
      expect(package1['error'][0]['trace']).to_not be_nil
    end
  end
end
