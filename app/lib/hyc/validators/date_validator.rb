module Hyc::Validators
  # Grad year validation
  class DateValidator < ActiveModel::Validator
    def validate(record)
      return if !record.date_created.present? || valid_value(record)

      add_error_message(record)
    end

    private

    def valid_value(record)
      # \w{0,}\s{0,}\d{4}s? matches Spring 2000, July 2000, 2000, 2000s, circa 2000
      # \d{4}(\\|\/|-)\d{2}(\\|\/|-)\d{2} matches 2000-01-01, 2000/01/01, 2000\01\01
      # \d{2}(\\|\/|-)\d{2}(\\|\/|-)\d{4} matches 01-01-2000, 01/01/2000, 01\01\2000
      # \d{4}\s{0,}\w+\s{0,}\d{4} matches 2000 to 2010, 2000 or 2001
      # \w+\s+\d{1,2}\w{0,2},?\s{0,}\d{4} matches July 1st 2000, July 1st, 2000, July 1 2000, July 1, 2000
      # [Uu]nknown) matches Unknown, unknown
      date_regex = /^(\w{0,}\s{0,}\d{4}s?|\d{4}(\\|\/|-)\d{2}(\\|\/|-)\d{2}|\d{2}(\\|\/|-)\d{2}(\\|\/|-)\d{4}|\d{4}\s{0,}\w+\s{0,}\d{4}|\w+\s+\d{1,2}\w{0,2},?\s{0,}\d{4}|[Uu]nknown)$/

      !record.date_created.to_s.match(date_regex).nil?
    end

    def add_error_message(record)
      record.errors['date_created'] << 'Please enter a valid date'
    end
  end
end