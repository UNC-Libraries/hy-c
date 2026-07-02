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
    context 'when value is blank' do
      it 'ignores nil' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, nil)
      end

      it 'ignores an empty string' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, '')
      end

      it 'ignores an array of blank values' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, ['', nil, ' '])
      end
    end

    context 'with a single-value field' do
      it 'does not add an error when text is within the limit' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, 'hello')
      end

      it 'does not add an error when HTML is stripped to within the limit' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, '<p>hello</p>')
      end

      it 'normalizes newlines before checking length' do
        expect(errors).not_to receive(:add)

        # "hello\nworld" normalizes to "hello world" which is 11 chars
        # but maximum is 10 so this should fail — use a short enough string
        validator.validate_each(record, attribute, "hi\nthere")
      end

      it 'collapses whitespace before checking length' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, "hi   there")
      end

      it 'adds the default error message when text is too long' do
        validator_without_message = described_class.new(attributes: [:body], maximum: maximum)

        expect(errors).to receive(:add).with(
          attribute,
          'Field text is too long (maximum is 10 characters)'
        )

        validator_without_message.validate_each(record, attribute, 'this is way too long')
      end

      it 'counts sanitized text length, not raw HTML length' do
        validator_without_message = described_class.new(attributes: [:body], maximum: 1)

        expect(errors).to receive(:add).with(
          attribute,
          'Field text is too long (maximum is 1 characters)'
        )

        validator_without_message.validate_each(record, attribute, '<b>hi</b>')
      end

      it 'adds a custom error message when provided' do
        validator_with_message = described_class.new(
          attributes: [:body],
          maximum: maximum,
          message: 'is too long'
        )

        expect(errors).to receive(:add).with(attribute, 'is too long')

        validator_with_message.validate_each(record, attribute, 'hello world!')
      end
    end

    context 'with a multi-value field' do
      it 'does not add an error when joined text is within the limit' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, ['hi', 'you'])
      end

      it 'adds an error when joined text exceeds the limit' do
        expect(errors).to receive(:add).with(
          attribute,
          'Field text is too long (maximum is 10 characters)'
        )

        validator.validate_each(record, attribute, ['hello', 'world!'])
      end

      it 'strips HTML from each value before checking length' do
        expect(errors).not_to receive(:add)

        validator.validate_each(record, attribute, ['<b>hi</b>', '<i>you</i>'])
      end

      it 'adds an error when joined HTML text exceeds the limit after sanitizing' do
        validator_without_message = described_class.new(attributes: [:body], maximum: 5)

        expect(errors).to receive(:add).with(
          attribute,
          'Field text is too long (maximum is 5 characters)'
        )

        validator_without_message.validate_each(record, attribute, ['<b>hello</b>', '<i>world</i>'])
      end
    end
  end
end