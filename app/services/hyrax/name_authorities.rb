module Hyrax
  # Provide select options for the creator field
  class NameAuthorities < QaSelectService
    def initialize
      super('names')
    end
  end
end