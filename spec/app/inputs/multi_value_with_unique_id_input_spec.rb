# frozen_string_literal: true
require 'rails_helper'

RSpec.describe MultiValueWithUniqueIdInput do
  let(:object) { double('object') }
  let(:builder) { double('builder', object: object) }
  let(:attribute_name) { 'description' }
  let(:value) { 'test value' }
  let(:input_dom_id) { 'description' }
  let(:input) do
    described_class.new(builder, attribute_name, nil, nil, {})
  end

  before do
    allow(input).to receive(:attribute_name).and_return(attribute_name)
    allow(input).to receive(:input_dom_id).and_return(input_dom_id)
  end

  describe '#build_field' do
    context 'when type is not textarea' do
      before do
        allow(input).to receive(:build_field_options).and_return({ class: [], type: 'text' })
        allow(builder).to receive(:text_field).and_return('<input type="text" />')
      end

      it 'generates a text field with unique ID' do
        expect(builder).to receive(:text_field).with(
          attribute_name,
          { class: ['multi_value'] }
        )

        result = input.build_field(value, 0)
        expect(result).to eq('<input type="text" />')
      end

      it 'generates a text field with ID matching the index' do
        expect(builder).to receive(:text_field).with(
          attribute_name,
          { class: ['multi_value'], id: "#{input_dom_id}_1" }
        )

        result = input.build_field(value, 1)
        expect(result).to eq('<input type="text" />')
      end
    end

    context 'when type is textarea' do
      before do
        allow(input).to receive(:build_field_options).and_return({ class: [], type: 'textarea' })
        allow(builder).to receive(:text_area).and_return('<textarea></textarea>')
      end

      it 'generates a textarea with unique ID' do
        expect(builder).to receive(:text_area).with(
          attribute_name,
          { class: ['multi_value'], id: "#{input_dom_id}_1" }
        )

        result = input.build_field(value, 1)
        expect(result).to eq('<textarea></textarea>')
      end
    end
  end
end
