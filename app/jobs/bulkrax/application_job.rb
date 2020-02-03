# frozen_string_literal: true

module Bulkrax
  class ApplicationJob < ActiveJob::Base
    include Sidekiq::Status::Worker
  end
end
