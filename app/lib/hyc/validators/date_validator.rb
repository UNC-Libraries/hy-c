module Hyc::Validators
  # Grad year validation
  class DateValidator < ActiveModel::Validator
    def validate(record)
      created = record.date_created.present?
      issued = record.date_issued.present?
      return unless created || issued

      if created
        return if valid_value(record, 'date_created')
        add_error_message(record, 'date_created')
      end

      if issued
        return if valid_value(record, 'date_issued')
        add_error_message(record, 'date_issued')
      end
    end

    private

    def valid_value(record, field)
      # [a-zA-Z]{0,}\s{0,}\d{4}s? matches Spring 2000, July 2000, 2000, 2000s, circa 2000
      # \d{4}(\\|\/|-)\d{2}(\\|\/|-)\d{2} matches 2000-01-01, 2000/01/01, 2000\01\01
      # \d{2}(\\|\/|-)\d{2}(\\|\/|-)\d{4} matches 01-01-2000, 01/01/2000, 01\01\2000
      # \d{4}\s{0,}[a-zA-Z]+\s{0,}\d{4} matches 2000 to 2010, 2000 or 2001
      # [a-zA-Z]+\s+\d{1,2}[a-zA-Z]{0,2},?\s{0,}\d{4} matches July 1st 2000, July 1st, 2000, July 1 2000, July 1, 2000
      # [Uu]nknown) matches Unknown, unknown
      date_regex = /^([a-zA-Z]{0,}\s{0,}\d{4}s?|\d{4}(\\|\/|-)\d{2}(\\|\/|-)\d{2}|\d{2}(\\|\/|-)\d{2}(\\|\/|-)\d{4}|\d{4}\s{0,}[a-zA-Z]+\s{0,}\d{4}|[a-zA-Z]+\s+\d{1,2}[a-zA-Z]{0,2},?\s{0,}\d{4}|[Uu]nknown|^$)\Z/
      !record[field].to_s.match(date_regex).nil?
    end

    def add_error_message(record, field)
      Rails.logger.info "#{field} was sumitted with an invalid date"
      record.errors[field] << 'Please enter a valid date'
    end
  end
end