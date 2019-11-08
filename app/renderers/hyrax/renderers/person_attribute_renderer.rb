module Hyrax
  module Renderers
    class PersonAttributeRenderer < AttributeRenderer
      def format_attribute(text)
        if text =~ /ORCID:.*?http/
          text_pieces = text.split(' ')
          url = text_pieces[1].strip
          text = "#{text_pieces[0]} <a href='#{url}'>#{url}</a>"
        end

        text
      end

      private

      def attribute_value_to_html(value)

        begin
          person = value.split('||')
          display_text = ''
          display_text << "<li><span#{html_attributes(microdata_value_attributes(field.to_s.chomp('_display')))}>#{person[0]}</span>"
          if person.length > 1
            display_text << '<ul>'
            person[1..-1].each do |attr|
              display_text << "<li>#{format_attribute(attr)}</li>"
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
