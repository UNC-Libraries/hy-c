# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/file_set_helper.rb
Hyrax::Statistics::Depositors::Summary.class_eval do
  def depositors
    # step through the array by twos to get each pair
    results.map do |key, deposits|
      user = ::User.find_by_user_key(key)
      # [hyc-override] log a warning rather than throwing an error if can't find a user
      if !user
        Rails.logger.warn("Unable to find user '#{key}'\nResults was: #{results.inspect}")
        nil
      else
        { key: key, deposits: deposits, user: user }
      end
    end.compact
  end
end
