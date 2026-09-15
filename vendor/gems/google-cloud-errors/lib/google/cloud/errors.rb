# frozen_string_literal: true

module Google
  module Cloud
	class Error < StandardError; end
	class CancelledError < Error; end
	class UnknownError < Error; end
	class InvalidArgumentError < Error; end
	class DeadlineExceededError < Error; end
	class NotFoundError < Error; end
	class AlreadyExistsError < Error; end
	class PermissionDeniedError < Error; end
	class UnauthenticatedError < Error; end
	class ResourceExhaustedError < Error; end
	class FailedPreconditionError < Error; end
	class AbortedError < Error; end
	class OutOfRangeError < Error; end
	class UnimplementedError < Error; end
	class InternalError < Error; end
	class UnavailableError < Error; end
	class DataLossError < Error; end

	# Keep a namespace compatible with code that references version info.
	module Errors
	end
  end
end

require 'google/cloud/errors/version'
