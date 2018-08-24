module HyraxHelper
  include ::BlacklightHelper
  include Hyrax::BlacklightOverride
  include Hyrax::HyraxHelperBehavior

  def language_links(options)
    unless /iso639-2/.match(options.to_s).nil?
      begin
        to_sentence(options[:value].map { |lang| link_to LanguagesService.label(lang), main_app.search_catalog_path(f: { language_sim: [lang] })})
      rescue
        nil
      end
    end
  end
end
