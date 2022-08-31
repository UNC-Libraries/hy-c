# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::PublicationVersionsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns only active terms' do
      expect(service.select_all_options).to include(['Preprint', 'preprint'], ['Postprint', 'postprint'],
                                                    ['Publisher', 'publisher'])
    end
  end

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('postprint')).to eq('Postprint')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.label('other')).to eq('Other Version')
    end
  end
end
