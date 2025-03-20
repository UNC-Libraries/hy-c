# frozen_string_literal: true
class MultiValueWithUniqueIdInput < MultiValueInput
  def build_field(value, index)
    options = build_field_options(value, index)

    # Generate a unique ID using the field name and index
    if index > 0
      options[:id] = "#{input_dom_id}_#{index}"
    end
    # Add multi_value class since many parts of the UI rely on it
    options[:class] << 'multi_value'

    if options.delete(:type) == 'textarea'.freeze
      result = @builder.text_area(attribute_name, options)
    else
      result = @builder.text_field(attribute_name, options)
    end
    return result
  end
end
