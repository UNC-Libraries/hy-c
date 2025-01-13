module Hyrax
  module Renderers
    class PersonAttributeRenderer < AttributeRenderer
      include HycHelper

      def render_dl_row
        markup = ''

        return markup if values.blank? && !options[:include_empty]

        markup << %(<dt>#{label}</dt>\n<dd><ul class='tabular'>)
        attributes = microdata_object_attributes(field).merge(class: "attribute attribute-#{field}")
        sort_people_by_index(values).each do |value|
          markup << "<li#{html_attributes(attributes)}>#{attribute_value_to_html(value.to_s)}</li>"
        end

        markup << %(</ul></dd>)
        # Add 'itemprop' to default list of allowed attributes
        sanitize markup, attributes: %w(href src width height alt cite datetime title class name xml:lang abbr itemprop itemtype target)
      end

      private

      def attribute_value_to_html(value)
        person = value.split('||')
        display_text = ''
        display_text << "<li><span#{html_attributes(microdata_value_attributes(field.to_s.chomp('_display')))}>#{person[1]}</span>"
        if person.length > 2
          display_text << '<ul>'
          person[2..-1].each do |attr|
            display_text << "<li>#{format_attribute(attr)}</li>"
          end
          display_text << '</ul>'
        end

        display_text << '</li>'
      rescue ArgumentError
        value
      end

      def format_attribute(text)
        if text =~ /ORCID:.*?http/
          text_pieces = text.split(' ')
          url = text_pieces[1].strip
          text = "#{text_pieces[0]} <a href='#{url}' target='_blank'>#{url}</a>"
        elsif text =~ /Affiliation:/
          # Get the full hierarchy of terms, with correct short labels, for the affiliation id
          term = DepartmentsService.term(text.split(':').last.strip)
          if term.present?
            text = term.split(';').map do |term_val|
              DepartmentsService.short_label(term_val.strip)
            end.join(', ')
          end
        end

        text
      end
    end
  end
end
