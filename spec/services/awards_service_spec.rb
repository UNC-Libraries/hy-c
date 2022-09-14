# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::AwardsService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['Honors', 'Honors'], ['Highest Honors', 'Highest Honors'],
                                                    ['Honors', 'With Honors'], ['Highest Honors', 'With Highest Honors'])
    end
  end

  describe '#select_active_options' do
    it 'returns all active terms' do
      expect(service.select_active_options).to include(['Honors', 'Honors'], ['Highest Honors', 'Highest Honors'])
    end

    it 'does not return inactive terms' do
      expect(service.select_active_options).not_to include(['Honors', 'With Honors'], ['Highest Honors', 'With Highest Honors'])
    end
  end

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('Honors')).to eq('Honors')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.label('With Honors')).to eq('Honors')
    end
  end
end
