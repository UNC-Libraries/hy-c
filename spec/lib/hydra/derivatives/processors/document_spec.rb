# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/image_source_data.rb')

RSpec.describe Hydra::Derivatives::Processors::Document do
  subject { described_class.new(source_path, directives) }
  PID = 991234

  let(:source_path)    { File.join(fixture_path, 'test.doc') }
  let(:output_service) { Hyrax::PersistDerivatives }

  describe '#encode_file' do
    context 'when converting to another format' do
      let(:directives)     { { format: 'png' } }
      let(:expected_tmp_dir) { File.join(Hydra::Derivatives.temp_file_base, '160974000') }
      let(:expected_tmp_file) { File.join(expected_tmp_dir, 'test.png') }
      let(:mock_content)   { 'mocked png content' }

      before do
        allow(File).to receive(:open).with(expected_tmp_file, 'rb').and_return(mock_content)
      end

      it 'creates a thumbnail of the document' do
        allow(output_service).to receive(:call).with(mock_content, directives)
        expect(File).to receive(:unlink).with(expected_tmp_file)
        allow(Time).to receive_message_chain(:now, :nsec).and_return(160974000)
        expect(FileUtils).to receive(:mkdir).with(expected_tmp_dir)
        expect(FileUtils).to receive(:rmdir).with(expected_tmp_dir)
        subject.encode_file('png')
      end
    end
  end

  describe '.encode' do
    let(:path) { '/path/to/document.pptx' }
    let(:format) { 'pdf' }
    let(:outdir) { '/output/dir' }
    let(:timeout) { 5 }

    before do
      # Mock the Hydra::Derivatives.libreoffice_path
      allow(Hydra::Derivatives).to receive(:libreoffice_path).and_return('/fake/path/to/soffice')
    end

    context 'when the process completes successfully' do
      it 'runs the command and completes without timeout' do
        # Mock Process.spawn and Process.wait to simulate successful execution
        allow(Hydra::Derivatives::Processors::Document).to receive(:execute_without_timeout).and_return(true)

        described_class.encode(path, format, outdir, timeout)

        # Verify that the process was executed
        expect(Hydra::Derivatives::Processors::Document).to have_received(:execute_without_timeout)
      end
    end

    context 'when the process times out' do
      it 'kills the process after a timeout' do
        # Mock Process.kill to simulate killing the process
        allow(Process).to receive(:kill)
        allow(Process).to receive(:wait).with(PID)
        allow(Hydra::Derivatives::Processors::Document).to receive(:execute_without_timeout).and_wrap_original do |original_method, command, context|
          # Simulate setting the PID in the context hash
          context[:pid] = PID
          # Raise the Timeout::Error
          sleep 2
        end
        allow(Hydra::Derivatives::Processors::Document).to receive(:system).with("ps -p #{PID}").and_return(true)

        expect do
          described_class.encode(path, format, outdir, 0.5)
        end.to raise_error(SofficeTimeoutError, /Unable to execute command.*/)

        # Verify that the process was spawned
        expect(Process).to have_received(:kill).with('TERM', PID) # Attempted graceful termination
        expect(Process).to have_received(:kill).with('KILL', PID) # Force kill if necessary
        # Verify that process was reaped after being killed
        expect(Process).to have_received(:wait).with(PID)
      end
    end

    context 'when another job already has lock' do
      let(:lock_manager) { instance_double(Redlock::Client) }
      let(:lock_key) { 'soffice:document_conversion' }

      before do
        stub_const('LOCK_MANAGER', lock_manager)
        allow(described_class).to receive(:execute_with_timeout)
      end

      it 'it waits to acquire the lock and then runs the command' do
        # Set up the locking block to indicate its locked twice, and then unlocked on the third attempt
        lock_attempts = 0
        allow(lock_manager).to receive(:lock).with(lock_key, anything) do |_key, _timeout, &block|
          lock_attempts += 1
          if lock_attempts == 3
            block.call({ validity: 3000, resource: lock_key, value: 'lock_value' })
          else
            block.call(false)
          end
        end

        described_class.encode(path, format, outdir, timeout)

        # Verify lock was called multiple times
        expect(lock_manager).to have_received(:lock).exactly(3).times
        # Verify that the process was executed after those retries
        expect(Hydra::Derivatives::Processors::Document).to have_received(:execute_with_timeout)
      end
    end
  end
end
