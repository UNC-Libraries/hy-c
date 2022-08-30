# frozen_string_literal: true
# Include hyc-specific helper code here instead of in the HyraxHelper to avoid circular dependencies
module HycHelper
  def language_links(options)
    language_link_array = options[:value].map do |lang|
      lang_label = LanguagesService.label(lang)
      link_to lang_label, main_app.search_catalog_path(f: { language_sim: [lang] }) unless lang_label.nil?
    end

    if language_link_array.compact.blank?
      nil
    else
      to_sentence(language_link_array)
    end
  end

  def language_links_facets(options)
    lang_label = LanguagesService.label(options)
    options = lang_label unless lang_label.nil?
    options
  end

  def get_work_url(model, id)
    Rails.application.routes.url_helpers.send("#{Hyrax::Name.new(model).singular_route_key}_url", id)
  end

  def sort_people_by_index(values)
    Array(values.sort_by { |person| person.split('||').first.split(':').last.to_i })
  end
end
