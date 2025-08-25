# frozen_string_literal: true
module LogUtilsHelper
  def self.double_log(msg, level = :info, tag: nil)
    tag = tag ? "[#{tag}] " : ''
    tagged = "#{tag}#{msg}"
    puts tagged
    case level
    when :warn then Rails.logger.warn(tagged)
    when :error then Rails.logger.error(tagged)
    else Rails.logger.info(tagged)
    end
  end

  def self.single_log(msg, level = :irnfo, tag: nil)
    tag = tag ? "[#{tag}] " : ''
    tagged = "#{tag}#{msg}"
    case level
    when :warn then Rails.logger.warn(tagged)
    when :error then Rails.logger.error(tagged)
    else Rails.logger.info(tagged)
    end
  end
end
