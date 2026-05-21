# frozen_string_literal: true
require 'rails_helper'

RSpec.describe WcagComplianceService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['WCAG 2.0 Level AA', 'WCAG 2.0 Level AA'],
                                                    ['WCAG 2.1 Level AAA', 'WCAG 2.1 Level AAA'],
                                                    ['WCAG 2.2 Level A', 'WCAG 2.2 Level A'])
    end
  end

  describe '#label' do
    it 'resolves for ids of terms' do
      expect(service.label('WCAG 2.1 Level AA')).to eq('WCAG 2.1 Level AA')
    end
  end
end
