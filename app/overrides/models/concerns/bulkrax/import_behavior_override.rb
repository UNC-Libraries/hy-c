# frozen_string_literal: true
# https://github.com/samvera-labs/bulkrax/blob/v4.4.0/app/models/concerns/bulkrax/import_behavior.rb
Bulkrax::ImportBehavior.module_eval do
  # [hyc-override] Permitting controlled vocabs on single value fields
  # Upstream PR: https://github.com/samvera-labs/bulkrax/pull/696
  def sanitize_controlled_uri_values!
    Bulkrax.qa_controlled_properties.each do |field|
      next if parsed_metadata[field].blank?

      if multiple?(field)
        parsed_metadata[field].each_with_index do |value, i|
          next if value.blank?
          parsed_metadata[field][i] = sanitize_controlled_uri_value(field, value)
        end
      else
        parsed_metadata[field] = sanitize_controlled_uri_value(field, parsed_metadata[field])
      end
    end

    true
  end

  def sanitize_controlled_uri_value(field, value)
    if (validated_uri_value = validate_value(value, field))
      validated_uri_value
    else
      debug_msg = %(Unable to locate active authority ID "#{value}" in config/authorities/#{field.pluralize}.yml)
      Rails.logger.debug(debug_msg)
      error_msg = %("#{value}" is not a valid and/or active authority ID for the :#{field} field)
      raise ::StandardError, error_msg
    end
  end
end
