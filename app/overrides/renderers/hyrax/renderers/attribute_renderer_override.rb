# frozen_string_literal: true

# [hyc-override] Overriding default. Show the language term instead of the saved value.
# Allow itemprop to be rendered
# https://github.com/samvera/hyrax/blob/v2.9.6/app/renderers/hyrax/renderers/attribute_renderer.rb
Hyrax::Renderers::AttributeRenderer.class_eval do
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
