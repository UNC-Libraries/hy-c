# frozen_string_literal: true
module Hyrax
  module Renderers
    class FormattedTextRenderer < AttributeRenderer
      private
      def attribute_value_to_html(value)
        sanitized_value = get_sanitized_string(value)
        if microdata_value_attributes(field).present?
          "<span#{html_attributes(microdata_value_attributes(field))}>#{sanitized_value}</span>"
        else
          li_value(sanitized_value)
        end
      end

      # Sanitize the value, allowing only safe HTML tags and attributes
      def get_sanitized_string(string)
         # Define allowed tags and attributes
        allowed_tags = %w[strong em b i u p br small mark sub sup a ul ol li dl dt dd div span h1 h2 h3 h4 h5 h6 blockquote]
        allowed_attributes = %w[href style]
        sanitize(string, tags: allowed_tags, attributes: allowed_attributes)
      end

    # Same as attribute renderer override, but without escaping the value
      def li_value(value)
        field_value = find_language(value) || value
        # Use get_sanitized_string instead of auto_link sanitization to preserve HTML tags (specifically underline)
        get_sanitized_string(field_value)
        auto_link(field_value, sanitize: false)
      end
    end
  end
end
