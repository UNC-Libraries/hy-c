# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::EditionsService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['Preprint', 'Preprint'], ['Publisher', 'Publisher'],
                                                    ['Postprint', 'Postprint'])
    end
  end

  describe '#label' do
    it 'resolves for ids of terms' do
      expect(service.label('Postprint')).to eq('Postprint')
    end
  end
end
