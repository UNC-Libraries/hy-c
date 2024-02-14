# [hyc-override] Downgrading certain errors that we do not need to receive as FATAL
# https://github.com/rails/rails/blob/v6.1.7.6/actionpack/lib/action_dispatch/middleware/debug_exceptions.rb
module ActionDispatch
  class DebugExceptions
    alias_method :old_log_error, :log_error
    def log_error(request, wrapper)
      if should_reduce_log_level?(wrapper)
        logger(request).send(:warn, "[404] #{wrapper.exception.class.name} (#{wrapper.exception.message})")
      else
        old_log_error request, wrapper
      end
    end

    def should_reduce_log_level?(wrapper)
      return true if wrapper.exception.is_a? ActionController::RoutingError
      return true if wrapper.exception.is_a? ActionController::BadRequest
      return true if wrapper.exception.is_a? ActionDispatch::Http::Parameters::ParseError
      return true if wrapper.exception.is_a? ActionDispatch::Http::MimeNegotiation::InvalidType
      return true if wrapper.exception.is_a? Ldp::Gone
      return true if wrapper.exception.is_a? BlacklightRangeLimit::InvalidRange
      return true if wrapper.exception.is_a? Riiif::ConversionError
      return false
    end
  end
end