# frozen_string_literal: true
# [hyc-override] Downgrading certain errors that we do not need to receive as FATAL
# https://github.com/rails/rails/blob/v6.1.7.6/actionpack/lib/action_dispatch/middleware/debug_exceptions.rb
module ActionDispatch
  class DebugExceptions
    alias_method :old_log_error, :log_error
    def log_error(request, wrapper)
      if should_reduce_log_level?(wrapper)
        logger(request).send(:warn, "[404] #{wrapper.exception.class.name} (#{wrapper.exception.message})")
      else
        old_log_error(request, wrapper)
      end
    end

    DEFATALIZED_CLASSES = [
      ActionController::BadRequest,
      ActionController::InvalidAuthenticityToken,
      ActionController::RoutingError,
      ActionController::UnknownFormat,
      ActionDispatch::Http::MimeNegotiation::InvalidType,
      ActionDispatch::Http::Parameters::ParseError,
      ActiveFedora::ObjectNotFoundError,
      Blacklight::Exceptions::RecordNotFound,
      BlacklightRangeLimit::InvalidRange,
      Faraday::TimeoutError,
      Hyrax::ObjectNotFoundError,
      Ldp::Gone,
      Riiif::ConversionError,
      Riiif::ImageNotFoundError
    ].to_set

    def should_reduce_log_level?(wrapper)
      return true if DEFATALIZED_CLASSES.include?(wrapper.exception.class)
    end
  end
end
