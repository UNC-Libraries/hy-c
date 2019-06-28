module Hyc
  module EdtfYearIndexer
    def self.index_dates(value)
      humanized_date = Hyc::EdtfConvert.convert_from_edtf(value)
      years = humanized_date.scan(/\d{4}/).map { |y| y.to_i }

      # Date ranges
      unless humanized_date.match(/to/).nil?
        years = years.each_slice(2).to_a
        return years.map { |y| (y.first..y.last).to_a }.flatten
      end

      # Decades
      unless humanized_date.match(/[1-9]0s$/).nil?
        return year_range(humanized_date, 'decade')
      end

      # Centuries
      unless humanized_date.match(/00s$/).nil?
        return year_range(humanized_date, 'century')
      end

      years
    end

    # Year range for decades and centuries
    private_class_method def self.year_range(humanized_date, type)
      if type == 'century'
        start_suffix = '00'
        end_suffix = '99'
        regex = /\d{2}/
      else
        start_suffix = '0'
        end_suffix = '9'
        regex = /\d{3}/
      end

      years = humanized_date.match(Regexp.new(regex))
      start = "#{years[0]}#{start_suffix}".to_i
      last = "#{years[0]}#{end_suffix}".to_i

      (start..last).to_a
    end
  end
end