# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::LanguagesService do
  before do
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns all terms' do
      expect(service.select_all_options).to include(['English', 'http://id.loc.gov/vocabulary/iso639-2/eng'],
                                                    ['Afar', 'http://id.loc.gov/vocabulary/iso639-2/aar'],
                                                    ['Abkhazian', 'http://id.loc.gov/vocabulary/iso639-2/abk'])
    end
  end

  describe '#label' do
    it 'resolves for ids of terms' do
      expect(service.label('http://id.loc.gov/vocabulary/iso639-2/eng')).to eq('English')
    end

    it 'returns nil for blank input' do
      expect(service.label('')).to be_nil
    end
  end

  describe '#iso639_1' do
    it 'resolves for ids of terms' do
      expect(service.iso639_1('http://id.loc.gov/vocabulary/iso639-2/eng')).to eq('en')
    end

    it 'returns nil for blank input' do
      expect(service.iso639_1('')).to be_nil
    end
  end
end
