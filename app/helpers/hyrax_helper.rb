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

  def redirect_lookup(column, id)
    if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
      redirect_uuids = File.read(ENV['REDIRECT_FILE_PATH'])
    else
      redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
    end

    csv = CSV.parse(redirect_uuids, headers: true)
    csv.find { |row| row[column].match(id) }
  end
end
