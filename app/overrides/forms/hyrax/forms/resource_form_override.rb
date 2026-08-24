# frozen_string_literal: true
# [hyc-override] Fix file loading issue. uninitialized constant Hyrax::Forms::ResourceForm::CompoundFieldBehavior (NameError)
# @TODO: Can remove when this is fixed upstream.
module ResourceFormCompoundFieldOverride
  include ::CompoundFieldBehavior
end
Hyrax::Forms::ResourceForm.prepend(ResourceFormCompoundFieldOverride)
