# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TextLengthValidator do
  subject(:validator) do
    described_class.new(attributes: [:body], maximum: maximum, message: message)
  end

  let(:record) { instance_double('Record', errors: errors) }
  let(:errors) { instance_double('Errors', add: true) }
  let(:attribute) { :body }
  let(:maximum) { 10 }
  let(:message) { nil }

  describe '#validate_each' do
    it 'ignores blank values' do
      expect(errors).not_to receive(:add)

      validator.validate_each(record, attribute, ['', nil, ' '])
    end

    it 'does not add an error for single-value text within the limit' do
      expect(errors).not_to receive(:add)

      validator.validate_each(record, attribute, '<p>hello</p>')
    end

    it 'does not add an error for multi-value text within the limit' do
      expect(errors).not_to receive(:add)

      validator.validate_each(record, attribute, ['hello', 'world'])
    end

    it 'adds the default error message when text is too long' do
      validator_without_message = described_class.new(attributes: [:body], maximum: maximum)

      expect(errors).to receive(:add).with(
        attribute,
        'Field text is too long (maximum is 10 characters)'
      )

      validator_without_message.validate_each(record, attribute, 'this is way too long')
    end

    it 'adds a custom error message when provided' do
      validator_with_message = described_class.new(
        attributes: [:body],
        maximum: maximum,
        message: 'is too long'
      )

      expect(errors).to receive(:add).with(attribute, 'is too long')

      validator_with_message.validate_each(record, attribute, 'hello world')
    end

    it 'checks cleaned text length rather than raw HTML length' do
      validator_without_message = described_class.new(attributes: [:body], maximum: 1)

      expect(errors).to receive(:add).with(
        attribute,
        'Field text is too long (maximum is 1 characters)'
      )

      validator_without_message.validate_each(record, attribute, '<b>hi</b>')
    end

    it 'does not count whitespace toward the maximum length' do
      validator_without_message = described_class.new(attributes: [:body], maximum: 3)

      expect(errors).not_to receive(:add)

      validator_without_message.validate_each(record, attribute, 'a b c')
    end
  end
end
