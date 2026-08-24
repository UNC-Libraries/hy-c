# frozen_string_literal: true
# [hyc-override] Temporary shim for Hyrax 5.3.0.
module Hyrax
  # [hyc-override] Temporary shim for Hyrax 5.3.0.
  #
  # `Hyrax::Forms::ResourceForm` includes `CompoundFieldBehavior`, but the gem
  # does not ship a definition for that module. Define a no-op behavior in the
  # `Hyrax` namespace so Ruby constant lookup from inside
  # `Hyrax::Forms::ResourceForm` resolves cleanly under Rails 7 / Zeitwerk.
  #
  # @TODO: Remove this once upstream Hyrax provides the module or removes the include.
  module CompoundFieldBehavior
  end
end
