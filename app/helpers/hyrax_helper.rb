module HyraxHelper
  include ::BlacklightHelper
  include Hyrax::BlacklightOverride
  include Hyrax::HyraxHelperBehavior

  def language_links(options)
    begin
      to_sentence(options[:value].map { |lang| link_to LanguagesService.label(lang), main_app.search_catalog_path(f: { language_sim: [lang] })})
    rescue KeyError
      nil
    end
  end

  def language_links_facets(options)
    begin
      link_to LanguagesService.label(options), main_app.search_catalog_path(f: { language_sim: [options] })
    rescue KeyError
      options
    end
  end
end
