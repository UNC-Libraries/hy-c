# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < Hyrax::Forms::WorkForm
    self.model_class = ::HonorsThesis
    self.terms += [:resource_type]
  end
end
