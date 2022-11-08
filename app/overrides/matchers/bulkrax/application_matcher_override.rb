# frozen_string_literal: true

require 'language_list'

# [hyc-override] remove : as a split token
Bulkrax::ApplicationMatcher.class_eval do
  def process_split
    if self.split.is_a?(TrueClass)
      @result = @result.split(/\s*[;|]\s*/) # default split by ; |
    elsif self.split
      result = @result.split(Regexp.new(self.split))
      @result = result.map(&:strip)
    end
  end
end
