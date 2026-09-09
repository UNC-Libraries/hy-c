# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/lib/hydra/services/characterization_service_override.rb')

RSpec.describe Hydra::Works::CharacterizationService do
  describe '#append_property_value' do
    subject(:append_property_value) do
      service.send(:append_property_value, property, value)
    end

    let(:service) { described_class.allocate }
    let(:property) { :title }
    let(:value) { 'new value' }
    let(:setter) { "#{property}=" }
    let(:work_object) { double('work_object') }

    before do
      allow(service).to receive(:object).and_return(work_object)
      allow(work_object).to receive(:respond_to?).with(setter).and_return(true)
    end

    context 'when the current value is multi-valued' do
      it 'appends the incoming value to the existing array' do
        allow(work_object).to receive(:send).with(property).and_return(['existing'])
        expect(work_object).to receive(:send).with(setter, ['existing', 'new value'])
        append_property_value
      end
    end

    context 'when the current value is scalar' do
      let(:property) { :checksum }
      let(:value) { 'sha1:abc123' }
      let(:current_checksum) { Object.new }

      it 'sets the incoming value directly' do
        allow(work_object).to receive(:send).with(property).and_return(current_checksum)
        expect(work_object).to receive(:send).with(setter, value)
        append_property_value
      end
    end
  end
end
