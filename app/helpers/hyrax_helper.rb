module HyraxHelper
  include ::BlacklightHelper
  include Hyrax::BlacklightOverride
  include Hyrax::HyraxHelperBehavior

  def language_links(options)
    language_link_array = options[:value].map do |lang|
      lang_label = LanguagesService.label(lang)
      if !lang_label.nil?
        link_to lang_label, main_app.search_catalog_path(f: { language_sim: [lang] })
      end
    end

    if language_link_array.compact.blank?
      nil
    else
      to_sentence(language_link_array)
    end
  end

  def language_links_facets(options)
    lang_label = LanguagesService.label(options)
    if !lang_label.nil?
      link_to lang_label, main_app.search_catalog_path(f: { language_sim: [options] })
    else
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

  def get_work_url(model, id)
    Rails.application.routes.url_helpers.send(Hyrax::Name.new(model).singular_route_key + "_url", id)
  end
end
