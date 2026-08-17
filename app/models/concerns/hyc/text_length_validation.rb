# frozen_string_literal: true

class StrippedTextLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    cleaned = Array(value).join(' ')
    cleaned = ActionView::Base.full_sanitizer.sanitize(cleaned)
                              .gsub(/\r\n?|\n/, '')

    maximum = options.fetch(:maximum)
    return if cleaned.length <= maximum

    message = options[:message] || "is too long (maximum is #{maximum} characters)"
    record.errors.add(attribute, message)
  end
end
