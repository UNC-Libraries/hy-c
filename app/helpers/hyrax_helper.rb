module HyraxHelper
  include ::BlacklightHelper
  include Hyrax::BlacklightOverride
  include Hyrax::HyraxHelperBehavior

  def language_links(options)
    if not /iso639-2/.match(options.to_s).nil? && /SolrDocument/.match(options.to_s).nil?
      begin
        link_to LanguagesService.label(options), options
      rescue KeyError
        options
      end
    end
  end
end
