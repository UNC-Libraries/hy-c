module Hyc
  module EdtfConvert
    def convertToEdtf(field)
      case field
      when /^\d{4}s$/ # 1900s, 1980s
        normalized_string = (field[2].to_i == 0 && field[3].to_i == 0) ? "#{field[0...-3]}xx" : "#{field[0...-2]}x"
      when /^(\d{4}-\d{2}-\d{2}|\d{4})$/ # 2000-01-01 or 2000
        normalized_string = field
      when /^(\d{2})-(\d{2})-(\d{4})$/ # 01-01-2000
        normalized_string = "#{$3}-#{$1}-#{$2}"
      when /^(\d{4})(\s+to\s+|-)(\d{4})$/i # 1990 to 1995
        normalized_string = "#{$1}/#{$3}"
      when month_season_list_regex(true) # Spring 2000, Aug 2000, July 2000
        normalized_string = "#{$2}-#{month_season($1)}"
      when month_season_list_regex(false) # July 1 2000, July 1st 2000, July 1, 2000, July 1st, 2000
        day = $2.to_i < 10 ? "0#{$2}" : $2
        normalized_string = "#{$4}-#{month_season($1)}-#{day}"
      when /^circa\s+(\d{4})$/i # circa 2000
        normalized_string = "#{$1}~"
      when /^unknown$/i # unknown
        normalized_string = 'uuuu'
      when /^$/
        return
      else
        Rails.logger.warn "Unable to parse date for EDTF conversion '#{field}'"
        return
      end

      normalized_string
    end

    private

    def month_season(field)
      month_season_list[field.downcase.to_sym]
    end

    def month_season_list(full_list = true)
      months = {
          january: '01', jan: '01',
          february: '02', feb: '02',
          march: '03', mar: '03',
          april: '04', apr: '04',
          may: '05', june: '06', july: '07',
          august: '08', aug: '08',
          september: '09', sept: '09',
          october: '10', oct: '10',
          november: '11', nov: '11',
          december: '12', dec: '12'
      }

      seasons = {
          spring: '21', summer: '22',
          fall: '23', autumn: '23', winter: '24'
      }

      if full_list
        months.merge(seasons)
      else
        months
      end
    end

    def month_season_list_regex(use_full_list)
      list_values = month_season_list(use_full_list)

      if use_full_list
        Regexp.new("^(#{list_values.keys.join('|')})\\s*(\\d{4})$", Regexp::IGNORECASE)
      else
        Regexp.new("^(#{list_values.keys.join('|')})\\s+(\\d{1,2})(st|nd|rd|th)?,?\\s*(\\d{4})$", Regexp::IGNORECASE)
      end
    end
  end
end