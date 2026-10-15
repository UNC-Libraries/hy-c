# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/lib/wings/active_fedora_converter_override.rb')

RSpec.describe Wings::ActiveFedoraConverter do
  subject(:converter) { described_class.new(resource: resource) }

  let(:resource) { double('FileSet resource', attributes: { extracted_text_id: Valkyrie::ID.new('extracted-text') }) }
  let(:af_object) { double('ActiveFedora FileSet', files: files) }
  let(:files) { double('files association') }
  let(:file) { double('file') }

  before do
    allow(converter).to receive(:normal_attributes).and_return(files: [file])
    allow(af_object).to receive(:attributes=)
    allow(files).to receive(:build_or_set)
    allow(converter).to receive(:perform_lease_conversion)
    allow(converter).to receive(:perform_embargo_conversion)
  end

  it 'does not reassign extracted text while converting a FileSet' do
    expect(af_object).not_to receive(:extracted_text=)

    converter.send(:parse_attributes, af_object)

    expect(files).to have_received(:build_or_set).with([file])
  end
end
