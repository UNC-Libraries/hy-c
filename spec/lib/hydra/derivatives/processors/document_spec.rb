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
    let(:timeout) { 1 }

    before do
      # Mock the Hydra::Derivatives.libreoffice_path
      allow(Hydra::Derivatives).to receive(:libreoffice_path).and_return('/fake/path/to/soffice')
    end

    context 'when the process completes successfully' do
      it 'runs the command and completes without timeout' do
        # Mock Process.spawn and Process.wait to simulate successful execution
        allow(Process).to receive(:spawn).and_return(PID)
        allow(Process).to receive(:wait2).with(PID).and_return([PID, 0])

        described_class.encode(path, format, outdir, timeout)

        # Verify that the process was spawned
        expect(Process).to have_received(:spawn)
        expect(Process).to have_received(:wait2).with(PID)
      end
    end

    context 'when the process times out' do
      it 'kills the process after a timeout' do
        allow(Process).to receive(:spawn).and_return(PID)
        # Simulate timeout
        allow(Process).to receive(:wait2).with(PID).and_raise(Timeout::Error)
        allow(Process).to receive(:wait).with(PID)

        # Mock Process.kill to simulate killing the process
        allow(Process).to receive(:kill)
        allow(Hydra::Derivatives::Processors::Document).to receive(:system).with("ps -p #{PID}").and_return(true)

        expect do
          described_class.encode(path, format, outdir, timeout)
        end.to raise_error(SofficeTimeoutError, "soffice process timed out after #{timeout} seconds")

        # Verify that the process was spawned
        expect(Process).to have_received(:spawn)
        expect(Process).to have_received(:kill).with('TERM', PID) # Attempted graceful termination
        expect(Process).to have_received(:kill).with('KILL', PID) # Force kill if necessary
        # Verify that process was reaped after being killed
        expect(Process).to have_received(:wait).with(PID)
      end
    end

    context 'when the process returns error status' do
      it 'runs the command and throws an error' do
        allow(Process).to receive(:spawn).and_return(PID)
        allow(Process).to receive(:wait2).with(PID).and_return([PID, 1])

        expect do
          described_class.encode(path, format, outdir, timeout)
        end.to raise_error(/Unable to execute command.*Exit code: 1.*/)

        # Verify that the process was spawned
        expect(Process).to have_received(:spawn)
        expect(Process).to have_received(:wait2).with(PID)
      end
    end
  end
end
