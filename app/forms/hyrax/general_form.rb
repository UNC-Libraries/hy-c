# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < Hyrax::Forms::WorkForm
    self.model_class = ::General
    self.terms += [:resource_type]
  end
end
