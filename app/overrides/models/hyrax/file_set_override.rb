# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/3.5/app/models/hyrax/file_set.rb
Hyrax::FileSet.class_eval do
  class << self
    # [hyc-override] get work related to file set
    def work
      Hyrax.custom_queries.find_parent_work(resource: self)
    end
  end
end
