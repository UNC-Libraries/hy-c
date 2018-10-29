module Hyrax
  module Renderers
    class PersonAttributeRenderer < AttributeRenderer
      private

      def attribute_value_to_html(value)
        begin
          person = value.split(';')
          display_text = ''
          display_text << "<li>#{person[0]}"
          if person.length > 1
            display_text << '<ul>'
            person[1..-1].each do |attr|
              display_text << "<li>#{attr}</li>"
            end
            display_text << '</ul>'
          end
          display_text << '</li>'
        rescue ArgumentError
          value
        end
      end
    end
  end
end
