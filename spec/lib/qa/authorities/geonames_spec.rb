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
end
