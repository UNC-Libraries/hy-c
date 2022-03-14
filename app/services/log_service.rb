module LogService
  def self.log_level
    log_level = ENV['LOG_LEVEL']&.to_sym
    if log_level && valid_log_level?(log_level)
      log_level
    else
      :warn
    end
  end

  def self.valid_log_level?(log_level)
    valid_log_levels.include?(log_level)
  end

  def self.valid_log_levels
    [:debug, :info, :warn, :error, :fatal, :unknown]
  end
end
