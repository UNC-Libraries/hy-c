# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalForm < Hyrax::Forms::WorkForm
    self.model_class = ::Journal
    self.terms += [:resource_type]
  end
end
