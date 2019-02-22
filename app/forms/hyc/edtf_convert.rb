module Hyc
  module EdtfConvert
    def convertToEdtf(field)
      case field
      when /^\d{4}s$/ # 1900s, 1980s
        normalized_string = (field[3] == 0 && field[4] == 0) ? "#{field[0...-3]}xx" : "#{field[0...-2]}x"
      when /^(\d{4}-\d{2}-\d{2}|\d{4})$/ # 2000-01-01 or 2000
        normalized_string = field
      when /^\d{2}-\d{2}-\d{4}$/ # 01-01-2000
        date_parts = split_date(field, '-')
        normalized_string = "#{date_parts[2]}-#{date_parts[0]}-#{date_parts[1]}"
      when /^\d{4}(\s+to\s+|-)\d{4}$/i # 1990 to 1995
        date_parts = split_date(field, /(\s+to\s+|-)/)
        normalized_string = "#{date_parts[0]}/#{date_parts[1]}"
      when /^(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june|july|aug(ust)?|sept(ember)?|oct(ober)?|nov(ember)?|dec(ember)?|spring|summer|fall|winter|autumn)\s*\d{4}$/i # Spring 2000, Aug 2000, July 2000
        date_parts = split_date(field)
        normalized_string = "#{date_parts[1]}-#{month_season(date_parts[0])}"
      when /^(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june|july|aug(ust)?|sept(ember)?|oct(ober)?|nov(ember)?|dec(ember)?)\s+\d{1,2}(st|nd|rd|th)?,?\s*\d{4}$/i # July 1 2000, July 1st 2000, July 1, 2000, July 1st, 2000
        date_parts = split_date(field)
        month_of_year = date_parts[0] =~ /,$/ ? date_parts[0][0...-1].downcase : date_parts[0].downcase

        if !date_parts[1].match(/st|nd|rd|th/).nil?
          day_of_month = split_date(date_parts[1], /[a-zA-Z,]+/)[0]
          normalized_string = "#{date_parts[2]}-#{month_season(month_of_year)}-#{day_of_month}"
        else
          normalized_string = "#{date_parts[2]}-#{month_season(month_of_year)}-#{date_parts[1]}}"
        end
      when /^circa\s+\d{4}$/i # circa 2000
        date_parts = split_date(field)
        normalized_string = "#{date_parts[1]}~"
      when /^unknown$/i # unknown
        normalized_string = 'uuuu'
      when /^$/
        Rails.logger.warn "Nothing to parse date for EDTF conversion for #{field}"
        return
      else
        Rails.logger.warn "Unable to parse date for EDTF conversion for #{field}"
        return
      end

      normalized_string
    end

    private

    def split_date(date, split_on = /\s+/)
      date.split(split_on)
    end

    def month_season(field)
      month_season_list = {
        january: '01', jan: '01',
        february: '02', feb: '02',
        march: '03', mar: '03',
        april: '04', apr: '04',
        may: '05', june: '06', july: '07',
        august: '08', aug: '08',
        september: '09', sept: '09',
        october: '10', oct: '10',
        november: '11', nov: '11',
        december: '12', dec: '12',
        spring: '21', summer: '22',
        fall: '23', autumn: '23', winter: '24'
      }

      month_season_list[field.downcase.to_sym]
    end
  end
end