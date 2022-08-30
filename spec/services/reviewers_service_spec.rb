# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::ReviewersService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#label' do
    it 'resolves for ids of active terms' do
      expect(service.label('biology')).to eq('person1@example.com')
    end
  end
end
