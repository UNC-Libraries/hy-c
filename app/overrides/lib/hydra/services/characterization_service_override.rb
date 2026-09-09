# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-works/blob/v2.3.0/lib/hydra/works/services/characterization_service.rb
# [hyc-override] This override normalizes scalar and multi-value characterization fields, as some properties (e.g., checksum) are scalar objects,
# which raises an error when attempting to append values to them as if they were arrays.
# @todo this is an upstream bug that should be fixed in the hydra-works gem. This override can be removed once it is.
# @todo possibly also a bug in the active-fedora gem, as it should be able to handle appending values to scalar properties without raising an error.
require 'hydra/works/services/characterization_service'

Hydra::Works::CharacterizationService.class_eval do
  # [hyc-override] Normalize scalar and multi-value characterization fields.
  # Some properties (e.g., checksum) are scalar objects, so `current + [value]`
  # would raise when `current` is not an Array.
  def append_property_value(property, value)
    setter = "#{property}="
    return unless object.respond_to?(setter)

    current = object.send(property)

    # Keep mime_type single-valued by always taking the latest extracted value.
    if property != :mime_type && current.is_a?(Array)
      value = current + [value]
    end

    # We don't want multiple heights / widths; keep the maximum numeric value.
    if property == :height || property == :width
      value = Array(value).map(&:to_i).max.to_s
    end

    object.send(setter, value)
  end
end