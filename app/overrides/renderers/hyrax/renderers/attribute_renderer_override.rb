# frozen_string_literal: true

# [hyc-override] Overriding default. Show the language term instead of the saved value.
# Allow itemprop to be rendered
# https://github.com/samvera/hyrax/blob/v2.9.6/app/renderers/hyrax/renderers/attribute_renderer.rb
Hyrax::Renderers::AttributeRenderer.class_eval do
  # Draw the table row for the attribute
  def render
    markup = ''

    return markup if values.blank? && !options[:include_empty]

    markup += %(<tr><th>#{label}</th>\n<td><ul class='tabular'>)
    attributes = microdata_object_attributes(field).merge(class: "attribute attribute-#{field}")
    Array(values).each do |value|
      markup += "<li#{html_attributes(attributes)}>#{attribute_value_to_html(value.to_s)}</li>"
    end
    markup += %(</ul></td></tr>)
    # Add 'itemprop' to default list of allowed attributes
    sanitize markup, attributes: %w(href src width height alt cite datetime title class name xml:lang abbr itemprop itemtype target)
  end

  # Draw the dl row for the attribute
  def render_dl_row
    markup = ''

    return markup if values.blank? && !options[:include_empty]

    markup += %(<dt>#{label}</dt>\n<dd><ul class='tabular'>)
    attributes = microdata_object_attributes(field).merge(class: "attribute attribute-#{field}")
    Array(values).each do |value|
      markup += "<li#{html_attributes(attributes)}>#{attribute_value_to_html(value.to_s)}</li>"
    end
    markup += %(</ul></dd>)
    # Add 'itemprop' to default list of allowed attributes
    sanitize markup, attributes: %w(href src width height alt cite datetime title class name xml:lang abbr itemprop itemtype target)
  end

  def find_language(language)
    if !/iso639-2/.match(language).nil?
      begin
        LanguagesService.label(language)
      rescue KeyError
        language
      end
    else
      language
    end
  end

  private

  def li_value(value)
    field_value = find_language(value) || value
    auto_link(ERB::Util.h(field_value))
  end
end
