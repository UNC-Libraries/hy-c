# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DepartmentsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns only active terms' do
      expect(service.select_all_options).to include(['Biology', 'biology'], ['Chemistry', 'chemistry'],
                                                    ['History', 'history'],
                                                    ['Test short Carolina Center for Genome Sciences', 'Carolina Center for Genome Sciences'])
    end
  end

  describe '#term' do
    it 'resolves for ids of active terms' do
      expect(service.term('history')).to eq('History')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.term('example')).to eq('Some College; Example Department')
    end

    it 'returns nil for blank input' do
      expect(service.term('')).to be_nil
    end
  end

  describe '#identifier' do
    it 'resolves for labels of active terms' do
      expect(service.identifier('History')).to eq('history')
    end

    it 'returns nil for blank input' do
      expect(service.identifier('')).to be_nil
    end
  end

  describe '#short_label' do
    it 'resolves for ids of active terms' do
      expect(service.short_label('history')).to eq('History')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.short_label('example')).to eq('Example Department')
    end

    it 'returns nil for blank input' do
      expect(service.short_label('')).to be_nil
    end

    it 'logs but does not raise error for non-existent terms' do
      allow(Rails.logger).to receive(:debug)
      expect(service.short_label('not-a-department')).to be_nil
      expect(Rails.logger).to have_received(:debug)
    end
  end
end
