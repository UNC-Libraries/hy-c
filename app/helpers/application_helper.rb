# frozen_string_literal: true
module ApplicationHelper
  def sanitize_abstract_field(options = {})
    options[:value].map { |v| ActionController::Base.helpers.strip_tags(v) }.join(' and ')
  end
end
