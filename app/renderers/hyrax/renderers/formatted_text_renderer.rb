module Hyrax
    module Renderers
      class FormattedTextRenderer < AttributeRenderer
        private
        def attribute_value_to_html(value)
          # Define allowed tags and attributes
          allowed_tags = %w[strong em b i u p br small mark sub sup a ul ol li dl dt dd div span h1 h2 h3 h4 h5 h6]
          allowed_attributes = %w[href]
  
          # Sanitize the value, allowing only safe HTML tags and attributes
          # Allow for rendering of text as html for the sanitized value
          safe_value = sanitize(value, tags: allowed_tags, attributes: allowed_attributes).html_safe
  
          if microdata_value_attributes(field).present?
            "<span#{html_attributes(microdata_value_attributes(field))}>#{safe_value}</span>"
          else
            li_value(value)
          end
        end
      end
    end
end