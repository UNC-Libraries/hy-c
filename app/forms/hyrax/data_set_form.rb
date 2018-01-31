# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < Hyrax::Forms::WorkForm
    self.model_class = ::DataSet
    self.terms += [:resource_type]
  end
end
