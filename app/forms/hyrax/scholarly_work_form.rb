# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkForm < Hyrax::Forms::WorkForm
    self.model_class = ::ScholarlyWork
    self.terms += [:resource_type]
  end
end
