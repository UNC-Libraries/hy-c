# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight/blob/v7.33.1/app/controllers/search_history_controller.rb
class SearchHistoryController < ApplicationController
  include Blacklight::SearchHistory

  # [hyc-override] adding helper for range limits
  helper RangeLimitHelper
end
