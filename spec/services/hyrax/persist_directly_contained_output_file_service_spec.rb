# frozen_string_literal: true
# [hyc-override] Coverage for the fileset_for_directives override
# https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/services/hyrax/persist_directly_contained_output_file_service.rb
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/services/hyrax/persist_directly_contained_output_file_service_override.rb')

RSpec.describe Hyrax::PersistDirectlyContainedOutputFileService do
  let(:derivatives_path) { '/app/samvera/hyrax-webapp/derivatives' }
  let(:file_set_id) { '9593tv123' }
  let(:file_set) { instance_double(FileSet) }

  before do
    allow(Hyrax.config).to receive(:derivatives_path).and_return(derivatives_path)
  end

  describe '.fileset_for_directives' do
    let(:directives) do
      { url: "file://#{derivatives_path}/95/93/tv/12/3-extracted_text.txt", container: 'extracted_text' }
    end

    it 'extracts the file set id from the path and looks it up as an ActiveFedora object' do
      expect(Hyrax.query_service).to receive(:find_by_alternate_identifier)
        .with(alternate_identifier: file_set_id, use_valkyrie: false)
        .and_return(file_set)

      result = described_class.send(:fileset_for_directives, directives)

      expect(result).to eq(file_set)
    end

    context 'when the id cannot be extracted from the path' do
      let(:directives) { { url: 'file:///some/unrelated/path', container: 'extracted_text' } }

      it 'raises an error' do
        expect { described_class.send(:fileset_for_directives, directives) }
          .to raise_error(/Could not extract fileset id from path/)
      end
    end
  end

  describe '.retrieve_remote_file' do
    let(:directives) { { container: 'extracted_text' } }

    it 'builds the directly contained file from the ActiveFedora object returned by fileset_for_directives' do
      allow(file_set).to receive(:build_extracted_text).and_return(:built_file)

      result = described_class.send(:retrieve_remote_file, file_set, directives)

      expect(file_set).to have_received(:build_extracted_text)
      expect(result).to eq(:built_file)
    end
  end
end
