# [hyc-override] https://github.com/minimagick/minimagick/blob/v4.12.0/lib/mini_magick/image/info.rb
MiniMagick::Image::Info.class_eval do
  def parse_warnings(raw_info)
    return raw_info unless raw_info.split("\n").size > 1

    raw_info.split("\n").each do |line|
      # must match "%m %w %h %b"
      puts "Processing line: #{line}"
      if line.match?(/^[A-Z]+ \d+ \d+ \d+(|\.\d+)([KMGTPEZY]{0,1})B$/)
        return line
      elsif line.include?('Warning')
        puts "WARNING line: #{line}"
        # [hyc-override] Display warnings at info level
        Rails.logger.info "Warning logged for image: #{line}"
      else
        puts "ERROR line: #{line}"
        # [hyc-override] Display errors at warn level
        Rails.logger.warn("Error logged for image: #{line}")
      end
    end
    raise TypeError
  end
end
