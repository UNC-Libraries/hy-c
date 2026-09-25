# frozen_string_literal: true
require 'redis'
config = Rails.application.config_for(:redis)
# Store a shared Redis client in Rails' custom application configuration
# so it can be accessed throughout the application.
Rails.application.config.x.redis = Redis.new(config.merge(thread_safe: true))
