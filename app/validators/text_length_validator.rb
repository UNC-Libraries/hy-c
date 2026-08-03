# frozen_string_literal: true

class TextLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if blank_value?(value)

    cleaned_value = normalized_text(value)
    return if cleaned_value.length <= maximum_length

    record.errors.add(
      attribute,
      options[:message] || "Field text is too long (maximum is #{maximum_length} characters)"
    )
  end

  private

  def blank_value?(value)
    Array(value).all?(&:blank?)
  end

  def normalized_text(value)
    text = Array(value).join(' ')
    text = ActionView::Base.full_sanitizer.sanitize(text)
    text = text.gsub(/\r\n?|\n/, ' ')
    text.squeeze(' ').strip
  end

  def maximum_length
    options.fetch(:maximum)
  end
end
