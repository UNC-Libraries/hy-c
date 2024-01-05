# frozen_string_literal: true
require 'rails_helper'

describe Qa::Authorities::Geonames do
  before do
    described_class.username = 'dummy'
  end

  let(:authority) { described_class.new }

  describe '#build_query_url' do
    subject { authority.build_query_url('foo') }
    it { is_expected.to eq 'http://api.geonames.org/searchJSON?q=foo&username=dummy&maxRows=25' }
  end

  describe '.label' do
    subject { authority.label.call(item) }
    shared_examples 'correct label formatting' do |name, countryName, adminName1, fcode, expected_label|
      let(:item) do
        {
        'name' => name,
        'countryName' => countryName,
        'adminName1' => '',
        'fcode' => fcode
        }
      end
      it "formats the label correctly when fcode is #{fcode}" do
        is_expected.to eq expected_label
      end
    end

    context 'when fcode is not PCLI or PCLS' do
      include_examples 'correct label formatting', 'Chapel Rock', 'Falkland Islands', '', 'HLL', 'Chapel Rock, Falkland Islands'
    end
    context 'when fcode is PCLI' do
      include_examples 'correct label formatting', 'Canada', 'Canada', '', 'PCLI', 'Canada'
    end
    context 'when fcode is PCLS' do
      include_examples 'correct label formatting', 'Macao', 'Macao', '', 'PCLS', 'Macao'
    end
  end
end
