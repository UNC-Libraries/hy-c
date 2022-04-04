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
      expect(service.select_all_options).to include(['biology', 'biology'], ['chemistry', 'chemistry'],
                                                    ['history', 'history'])
    end
  end

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('history')).to eq('History')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.label('example')).to eq('Some College; Example Department')
    end
  end

  describe '#identifier' do
    it 'resolves for labels of active terms' do
      expect(service.identifier('History')).to eq('history')
    end
  end

  describe '#short_label' do
    it 'resolves for ids of active terms' do
      expect(service.short_label('history')).to eq('History')
      expect(service.short_label('example')).to eq('Example Department')
    end
  end
end
