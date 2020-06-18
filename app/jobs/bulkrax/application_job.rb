# [hyc-override] Override to allow bulkrax jobs to be available in sidekiq status ui
# frozen_string_literal: true

module Bulkrax
  class ApplicationJob < ActiveJob::Base
    include Sidekiq::Status::Worker
  end
end
