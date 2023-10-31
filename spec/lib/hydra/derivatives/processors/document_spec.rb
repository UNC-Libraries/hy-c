# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/image_source_data.rb')

RSpec.describe Hydra::Derivatives::Processors::Document do
  subject { described_class.new(source_path, directives) }

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
end
